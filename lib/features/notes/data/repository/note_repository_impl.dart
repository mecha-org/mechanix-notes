import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mechanix_notes/core/exceptions/objectbox_exception.dart';
import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/core/utils/constants.dart';
import 'package:mechanix_notes/core/utils/helper.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:mechanix_notes/features/notes/data/services/indexing_service.dart';
import 'package:mechanix_notes/features/notes/data/services/note_file_storage.dart';
import 'package:mechanix_notes/features/notes/data/services/note_tag_helper.dart';
import 'package:uuid/uuid.dart';

class NoteRepositoryImpl extends NoteRepository {
  final IndexingService _indexingService;
  final NoteFileStorage _fileStorage;

  NoteRepositoryImpl({
    Store? store,
    IndexingService? indexingService,
    NoteFileStorage? fileStorage,
  }) : _store = store,
       _indexingService = indexingService ?? IndexingService(),
       _fileStorage = fileStorage ?? NoteFileStorage();

  Future<void> ensureStoreConnected() async {
    try {
      await _indexingService.initialize();
    } catch (e) {
      AppLogger.e('Failed to initialize Tantivy store: $e');
    }

    try {
      await _fileStorage.ensureDirectoryExists();
    } catch (e) {
      AppLogger.e('Failed to initialize note file directory: $e');
    }
  }

  @override
  Future<List<NoteMetaData>> getNotes(int skip, int take) async {
    try {
      await ensureStoreConnected();
      final notes = await _indexingService.getNotes(skip: skip, take: take);

      if (notes.isEmpty) {
        AppLogger.i("No notes found");
        return [];
      }

      AppLogger.i(
        "Fetched notes page (skip: $skip, take: $take) → page size: ${notes.length}",
      );
      return notes;
    } catch (e) {
      AppLogger.e('Failed to fetch notes: $e');
      return [];
    }
  }

  @override
  Future<NoteMetaData?> getNoteMetaData(String id) async {
    try {
      await ensureStoreConnected();
      return _indexingService.getNoteMetaData(id);
    } catch (e) {
      AppLogger.e('Failed to fetch note metadata by id: $e');
      return null;
    }
  }

  @override
  Future<NoteModel?> getNoteById(String id) async {
    try {
      await ensureStoreConnected();
      final doc = _indexingService.getDocument(id);
      if (doc == null) {
        AppLogger.i('NoteRepository: getNoteById($id) → not found');
        return null;
      }

      final note = NoteModel(
        id: doc.id,
        title: doc.title,
        content: '',
        previewText: doc.previewText,
        fileName: doc.fileName,
        isPinned: doc.isPinned,
        createdAt: DateTime.fromMillisecondsSinceEpoch(doc.createdAt.toInt()),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(doc.updatedAt.toInt()),
      );

      // 1. Try reading using fileName
      String? markdown;
      final fileToRead = note.fileName;
      if (fileToRead != null && fileToRead.isNotEmpty) {
        markdown = await _fileStorage.readNoteContent(fileToRead);
      }

      // 2. Fallback: try resolving by title (e.g. if saved under title directly)
      if (markdown == null) {
        final titleFileName =
            '${NoteFileStorage.sanitizeFileName(note.title)}.md';
        if (await _fileStorage.noteFileExists(titleFileName)) {
          markdown = await _fileStorage.readNoteContent(titleFileName);
          if (markdown != null) {
            note.fileName = titleFileName;
            unawaited(
              _indexingService.upsertNote(note).catchError((e) {
                AppLogger.e(
                  'NoteRepository: Healing index update failed for ${note.id}: $e',
                );
              }),
            );
          }
        }
      }

      // 3. Fallback: Auto-heal by searching directory for embedded tag <!-- mechanix:id=id -->
      if (markdown == null) {
        final matchingFile = await _findNoteFileByIdTag(note.id);
        if (matchingFile != null) {
          markdown = matchingFile.content;
          note.fileName = matchingFile.fileName;
          final cleanContent = NoteTagHelper.stripTag(markdown);
          final lines = cleanContent
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList();
          if (lines.isNotEmpty) {
            final firstLineTitle = lines.first
                .replaceAll(RegExp(r'^#+\s*'), '')
                .trim();
            if (firstLineTitle.isNotEmpty) {
              note.title = firstLineTitle;
            }
          }
          unawaited(
            _indexingService.upsertNote(note).catchError((e) {
              AppLogger.e(
                'NoteRepository: Auto-heal index update failed for ${note.id}: $e',
              );
            }),
          );
          AppLogger.i(
            'NoteRepository: Auto-healed note ${note.id} to filename ${matchingFile.fileName}',
          );
        }
      }

      // 4. Return note with clean (stripped) content for editor and UI
      if (markdown != null) {
        final cleanContent = NoteTagHelper.stripTag(markdown);
        note.content = cleanContent;

        // Auto-reindex asynchronously in background if file was modified externally
        unawaited(
          _autoReindexIfModified(
            note: note,
            cleanContent: cleanContent,
            indexedUpdatedAtMillis: doc.updatedAt.toInt(),
          ),
        );
      } else if (note.fileName != null) {
        // Alternative 2: File confirmed missing from disk, purge ghost note from Tantivy on access
        AppLogger.i(
          'NoteRepository: Note $id (${note.fileName}) missing on disk. Purging ghost note from Tantivy...',
        );
        unawaited(
          _indexingService.deleteNotesBatch([id]).catchError((e) {
            AppLogger.e('NoteRepository: Failed to purge ghost note $id: $e');
          }),
        );
        return null;
      }

      AppLogger.i('NoteRepository: getNoteById($id) → found');
      return note;
    } catch (e) {
      AppLogger.e('NoteRepository: getNoteById failed: $e');
      return null;
    }
  }

  Future<void> _autoReindexIfModified({
    required NoteModel note,
    required String cleanContent,
    required int indexedUpdatedAtMillis,
  }) async {
    try {
      final fileToCheck = note.fileName;
      if (fileToCheck == null || fileToCheck.isEmpty) return;

      final fileModified = await _fileStorage.getFileLastModified(fileToCheck);
      final indexedUpdatedAt = DateTime.fromMillisecondsSinceEpoch(
        indexedUpdatedAtMillis,
      );

      if (fileModified != null &&
          fileModified.isAfter(
            indexedUpdatedAt.add(const Duration(seconds: 1)),
          )) {
        AppLogger.i(
          'NoteRepository: External edit detected on $fileToCheck ($fileModified > $indexedUpdatedAt). Auto-updating index in background...',
        );

        final (title, previewText) = _extractTitleAndPreview(
          cleanContent,
          note.title,
        );

        final updatedNote = NoteModel(
          id: note.id,
          title: title,
          content: cleanContent,
          previewText: previewText,
          fileName: note.fileName,
          isPinned: note.isPinned,
          createdAt: note.createdAt,
          updatedAt: fileModified,
        );

        await _indexingService.upsertNote(updatedNote);
      }
    } catch (e) {
      AppLogger.e('NoteRepository: Background auto-reindex failed: $e');
    }
  }

  /// Reads at most [maxBytes] from the end of [file] and decodes as UTF-8 without reading entire file contents into memory.
  Future<String?> _readTailString(File file, [int maxBytes = 1024]) async {
    RandomAccessFile? raf;
    try {
      final length = await file.length();
      if (length == 0) return '';
      raf = await file.open(mode: FileMode.read);
      final readLength = length < maxBytes ? length : maxBytes;
      await raf.setPosition(length - readLength);
      final bytes = await raf.read(readLength);
      return utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      return null;
    } finally {
      await raf?.close();
    }
  }

  /// Scans the notes directory for a .md file containing an embedded tag matching [noteId].
  Future<({String fileName, String content})?> _findNoteFileByIdTag(
    String noteId,
  ) async {
    try {
      final dir = _fileStorage.directory;
      if (!await dir.exists()) return null;

      final entities = await dir.list().toList();
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.md')) {
          final fileName = entity.uri.pathSegments.last;
          if (fileName.startsWith('..tmp_')) continue;

          final tail = await _readTailString(entity);
          if (tail != null && tail.contains('mechanix:id')) {
            final extractedId = NoteTagHelper.extractId(tail);
            if (extractedId == noteId) {
              final content = await entity.readAsString();
              return (fileName: fileName, content: content);
            }
          }
        }
      }
    } catch (e) {
      AppLogger.e(
        'NoteRepository: _findNoteFileByIdTag failed for $noteId: $e',
      );
    }
    return null;
  }

  @override
  Future<void> deleteNotes(List<String> ids) async {
    try {
      await ensureStoreConnected();

      for (final id in ids) {
        final doc = _indexingService.getDocument(id);
        if (doc != null) {
          final fileToDelete = doc.fileName;
          if (fileToDelete != null && fileToDelete.isNotEmpty) {
            await _fileStorage.deleteNoteFile(fileToDelete);
          } else {
            final titleFileName =
                '${NoteFileStorage.sanitizeFileName(doc.title)}.md';
            await _fileStorage.deleteNoteFile(titleFileName);
          }
        }
      }

      await _indexingService.deleteNotesBatch(ids);
      AppLogger.i('NoteRepository: deleteNotes(${ids.length})');
    } catch (e) {
      AppLogger.e('NoteRepository: deleteNotes failed: $e');
    }
  }

  @override
  Future<void> upsertNote(NoteModel note) async {
    try {
      await ensureStoreConnected();

      final existingDoc = _indexingService.getDocument(note.id);
      final currentFileName = existingDoc?.fileName ?? note.fileName;

      final cleanMarkdown = NoteTagHelper.stripTag(note.content);
      final taggedMarkdown = NoteTagHelper.appendTag(cleanMarkdown, note.id);
      final savedFileName = await _fileStorage.writeNoteContent(
        title: note.title,
        markdown: taggedMarkdown,
        currentFileName: currentFileName,
      );

      note.fileName = savedFileName;
      note.content = cleanMarkdown;
      note.plainText = plainText;

      await _indexingService.upsertNote(note);
      AppLogger.i(
        'NoteRepository: upsertNote(${note.id}) ${note.updatedAt} ${note.title} saved to $savedFileName ✓',
      );
    } on FileSystemException catch (e) {
      AppLogger.e(
        'NoteRepository: upsertNote failed due to filesystem error: $e',
      );
      rethrow;
    } catch (e) {
      AppLogger.e('NoteRepository: upsertNote failed: $e');
      rethrow;
    }
  }

  @override
  Future<List<String>> searchNoteIds(String query) async {
    try {
      await ensureStoreConnected();
      return await _indexingService.search(query);
    } catch (e) {
      AppLogger.e('Failed to search notes: $e');
      return [];
    }
  }

  @override
  Future<List<NoteMetaData>> getNotesMetaData(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      await ensureStoreConnected();
      final q = box.query(NoteModel_.id.oneOf(ids)).build();
      final dbNotes = await q.findAsync();
      q.close();

      // Restore the caller's order (search relevance); oneOf does not keep it
      final notesMap = {for (var note in dbNotes) note.id: note};
      return [
        for (final id in ids)
          if (notesMap[id] case final note?) _toMetaData(note),
      ];
    } catch (e) {
      AppLogger.e('Failed to load notes metadata: $e');
      return [];
    }
  }

  @override
  Future<bool> togglePinNote(String id) async {
    try {
      await ensureStoreConnected();
      final result = await _indexingService.togglePin(id);
      AppLogger.i('NoteRepository: togglePinNote($id) → $result');
      return result;
    } catch (e) {
      AppLogger.e('NoteRepository: togglePinNote failed: $e');
      return false;
    }
  }

  @override
  Future<List<NoteMetaData>> getNotesFromTantivy({int limit = 45}) async {
    return getNotes(0, limit);
  }

  (String title, String previewText) _extractTitleAndPreview(
    String cleanContent, [
    String? fallbackTitle,
  ]) {
    String title = fallbackTitle ?? '';
    String previewText = '';

    final plainText = markdownToPlainText(cleanContent);
    final lines = plainText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isNotEmpty) {
      final firstLine = lines.first.replaceAll(RegExp(r'^#+\s*'), '').trim();
      if (firstLine.isNotEmpty) {
        title = firstLine;
      }
      if (lines.length > 1) {
        final bodyText = lines.skip(1).join(' ');
        previewText = bodyText.length > Constants.notePreviewTextMaxLength
            ? bodyText.substring(0, Constants.notePreviewTextMaxLength)
            : bodyText;
      } else {
        previewText = firstLine.length > Constants.notePreviewTextMaxLength
            ? firstLine.substring(0, Constants.notePreviewTextMaxLength)
            : firstLine;
      }
    }
    return (title, previewText);
  }

  @override
  Future<int> syncNotesFromDisk() async {
    try {
      await ensureStoreConnected();
      final dir = _fileStorage.directory;
      if (!await dir.exists()) return 0;

      int updatedCount = 0;
      final entities = await dir.list().toList();
      final discoveredNoteIds = <String>{};

      for (final entity in entities) {
        if (entity is! File || !entity.path.endsWith('.md')) continue;
        final fileName = entity.uri.pathSegments.last;
        if (fileName.startsWith('..tmp_')) continue;

        try {
          final tail = await _readTailString(entity);
          String? noteId = tail != null ? NoteTagHelper.extractId(tail) : null;
          final fileStat = await entity.stat();
          final rawContent = await entity.readAsString();

          // Auto-tag untagged external files
          if (noteId == null) {
            noteId = const Uuid().v4();
            final tagged = NoteTagHelper.appendTag(rawContent, noteId);
            await entity.writeAsString(tagged);
          }
          discoveredNoteIds.add(noteId);

          final existingDoc = _indexingService.getDocument(noteId);
          final indexedUpdatedAt = existingDoc != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  existingDoc.updatedAt.toInt(),
                )
              : null;

          // Re-index if missing from Tantivy, renamed, or externally modified
          if (existingDoc == null ||
              existingDoc.fileName != fileName ||
              fileStat.modified.isAfter(
                indexedUpdatedAt!.add(const Duration(seconds: 1)),
              )) {
            final cleanContent = NoteTagHelper.stripTag(rawContent);
            final fallbackTitle = fileName.endsWith('.md')
                ? fileName.substring(0, fileName.length - 3)
                : fileName;
            final (title, previewText) = _extractTitleAndPreview(
              cleanContent,
              existingDoc?.title ?? fallbackTitle,
            );

            final note = NoteModel(
              id: noteId,
              title: title,
              content: cleanContent,
              previewText: previewText,
              fileName: fileName,
              createdAt: existingDoc != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      existingDoc.createdAt.toInt(),
                    )
                  : fileStat.modified,
              updatedAt: fileStat.modified,
              isPinned: existingDoc?.isPinned ?? false,
            );

            await _indexingService.upsertNote(note);
            updatedCount++;
            AppLogger.i(
              'NoteRepository: Reconciled $fileName (id: $noteId) into Tantivy',
            );
          }
        } catch (e) {
          AppLogger.e('NoteRepository: Failed to sync $fileName: $e');
        }
      }

      // Clean up ghost notes in Tantivy whose files were deleted on disk
      try {
        // Check if Tantivy has more notes than discovered files on disk.
        final hasGhosts = (await _indexingService.getNotes(
          skip: discoveredNoteIds.length,
          take: 1,
        )).isNotEmpty;

        if (hasGhosts) {
          final indexedNotes = await _indexingService.getNotes(
            skip: 0,
            take: 10000,
          );
          final ghostIds = indexedNotes
              .map((n) => n.id)
              .where((id) => !discoveredNoteIds.contains(id))
              .toList();
          if (ghostIds.isNotEmpty) {
            await _indexingService.deleteNotesBatch(ghostIds);
            updatedCount += ghostIds.length;
            AppLogger.i(
              'NoteRepository: Purged ${ghostIds.length} ghost notes from Tantivy',
            );
          }
        }
      } catch (e) {
        AppLogger.e('NoteRepository: Failed to purge ghost notes: $e');
      }

      return updatedCount;
    } catch (e) {
      AppLogger.e('NoteRepository: syncNotesFromDisk failed: $e');
      return 0;
    }
  }
}
