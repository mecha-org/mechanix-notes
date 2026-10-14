import 'dart:async';
import 'dart:io';

import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/core/utils/constants.dart';
import 'package:mechanix_notes/core/utils/helper.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:mechanix_notes/features/notes/data/services/indexing_service.dart';
import 'package:mechanix_notes/features/notes/data/services/note_directory_watcher.dart';
import 'package:mechanix_notes/features/notes/data/services/note_file_storage.dart';
import 'package:mechanix_notes/features/notes/data/services/note_tag_helper.dart';
import 'package:mechanix_notes/objectbox.g.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class NoteRepositoryImpl extends NoteRepository {
  Store? _store;
  Box<NoteModel>? _box;
  final IndexingService _indexingService;
  final NoteFileStorage _fileStorage;
  NoteDirectoryWatcher? _directoryWatcher;
  final StreamController<void> _directoryChangedController =
      StreamController<void>.broadcast();

  NoteRepositoryImpl({
    IndexingService? indexingService,
    NoteFileStorage? fileStorage,
    NoteDirectoryWatcher? directoryWatcher,
  }) : _indexingService = indexingService ?? IndexingService(),
       _fileStorage = fileStorage ?? NoteFileStorage(),
       _directoryWatcher = directoryWatcher;

  Box<NoteModel> get box {
    if (_box == null) {
      throw StateError(
        "Box is not initialized. Call ensureStoreConnected() first.",
      );
    }
    return _box!;
  }

  Future<void> ensureStoreConnected() async {
    if (_store != null && !_store!.isClosed()) return;

    try {
      await _initializeStore();
    } catch (e) {
      AppLogger.e('Failed to open ObjectBox store: $e');
      if (e is FileSystemException && e.message.contains('lock failed')) {
        throw ObjectBoxException("Failed to open ObjectBox store: $e");
      }
      rethrow;
    }

    try {
      await _indexingService.initialize();
    } catch (e) {
      AppLogger.e('Failed to initialize Tantivy: $e');
    }

    try {
      await _fileStorage.ensureDirectoryExists();
    } catch (e) {
      AppLogger.e('Failed to initialize note file directory: $e');
    }

    if (_directoryWatcher == null) {
      _directoryWatcher = NoteDirectoryWatcher(
        directory: _fileStorage.directory,
        isInternalWrite: _fileStorage.isInternalWrite,
        onDirectoryChanged: () async {
          await reconcileWithDisk();
          _directoryChangedController.add(null);
        },
      );
      _directoryWatcher!.start();
    } else if (!_directoryWatcher!.isWatching) {
      _directoryWatcher!.start();
    }
  }

  Future<void> _initializeStore() async {
    try {
      final home = Platform.environment['HOME'];
      final appDir = Directory('$home${Constants.notesDbPath}');
      final exists = await appDir.exists();

      if (!exists) {
        await appDir.create(recursive: true);
      }

      _store = await openStore(
        maxDBSizeInKB: Constants.maxDBSizeInKB,
        directory: appDir.path,
      );
      _box = _store!.box<NoteModel>();

      AppLogger.i('[NoteRepository] ObjectBox store opened at ${appDir.path}');
    } catch (e) {
      AppLogger.e('Failed to initialize ObjectBox store: $e');
      rethrow;
    }
  }

  @override
  Future<List<NoteMetaData>> getNotes(int skip, int take) async {
    try {
      await ensureStoreConnected();
      final queryBuilder = box.query()
        ..order(NoteModel_.isPinned, flags: Order.descending)
        ..order(NoteModel_.updatedAt, flags: Order.descending);
      final query = queryBuilder.build();
      query.offset = skip;
      query.limit = take;

      final notes = query.find();
      query.close();

      if (notes.isEmpty) {
        AppLogger.i("No notes found");
        return [];
      }

      final metaDataList = notes.map((note) {
        return NoteMetaData(
          id: note.id,
          height: note.height,
          title: note.title,
          createdAt: note.createdAt,
          updatedAt: note.updatedAt,
          previewText: note.previewText,
          isPinned: note.isPinned,
        );
      }).toList();

      AppLogger.i(
        "Fetched notes page (skip: $skip, take: $take) → page size: ${metaDataList.length}",
      );
      return metaDataList;
    } catch (e) {
      AppLogger.e('Failed to fetch notes: $e');
      return [];
    }
  }

  @override
  Future<NoteMetaData?> getNoteMetaData(String id) async {
    try {
      await ensureStoreConnected();
      final query = box.query(NoteModel_.id.equals(id)).build();
      final note = query.findFirst();
      query.close();
      if (note != null) {
        return NoteMetaData(
          id: note.id,
          height: note.height,
          title: note.title,
          createdAt: note.createdAt,
          updatedAt: note.updatedAt,
          previewText: note.previewText,
          isPinned: note.isPinned,
        );
      }
      return null;
    } catch (e) {
      AppLogger.e('Failed to fetch note metadata by id: $e');
      return null;
    }
  }

  @override
  Future<NoteModel?> getNoteById(String id) async {
    try {
      await ensureStoreConnected();
      final query = box.query(NoteModel_.id.equals(id)).build();
      final note = query.findFirst();
      query.close();
      if (note == null) {
        AppLogger.i('NoteRepository: getNoteById($id) → not found');
        return null;
      }

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
            box.put(note);
          }
        }
      }

      // 3. Fallback: Auto-heal by searching directory for embedded tag <!-- mechanix:id=id -->
      if (markdown == null) {
        final matchingFile = await _findNoteFileByIdTag(note.id);
        if (matchingFile != null) {
          markdown = matchingFile.content;
          note.fileName = matchingFile.fileName;
          // Update title from the file if available
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
          box.put(note);
          AppLogger.i(
            'NoteRepository: Auto-healed note ${note.id} to filename ${matchingFile.fileName}',
          );
        }
      }

      // 4. Return note with clean (stripped) content for editor and UI
      if (markdown != null) {
        note.content = NoteTagHelper.stripTag(markdown);
      } else {
        note.content = '';
        note.isFileMissing = true;
      }

      AppLogger.i('NoteRepository: getNoteById($id) → found');
      return note;
    } catch (e) {
      AppLogger.e('NoteRepository: getNoteById failed: $e');
      return null;
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

          final content = await entity.readAsString();
          final extractedId = NoteTagHelper.extractId(content);
          if (extractedId == noteId) {
            return (fileName: fileName, content: content);
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
      final query = box.query(NoteModel_.id.oneOf(ids)).build();
      final notesToDelete = query.find();
      query.close();

      for (final note in notesToDelete) {
        final fileToDelete = note.fileName;
        if (fileToDelete != null && fileToDelete.isNotEmpty) {
          await _fileStorage.deleteNoteFile(fileToDelete);
        } else {
          final titleFileName =
              '${NoteFileStorage.sanitizeFileName(note.title)}.md';
          await _fileStorage.deleteNoteFile(titleFileName);
        }
      }

      if (notesToDelete.isNotEmpty) {
        box.removeMany(notesToDelete.map((n) => n.obxId).toList());
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
      final query = box.query(NoteModel_.id.equals(note.id)).build();
      final existing = query.findFirst();
      query.close();
      if (existing != null) {
        note.obxId = existing.obxId;
      }

      final currentFileName = existing?.fileName;

      final cleanMarkdown = NoteTagHelper.stripTag(note.content);
      final taggedMarkdown = NoteTagHelper.appendTag(cleanMarkdown, note.id);
      final savedFileName = await _fileStorage.writeNoteContent(
        title: note.title,
        markdown: taggedMarkdown,
        currentFileName: currentFileName,
      );

      // Store fileName in ObjectBox and keep content empty in database
      note.fileName = savedFileName;
      note.content = '';
      box.put(note);

      // Restore clean markdown in in-memory note instance
      note.content = cleanMarkdown;

      await _indexingService.upsertNote(note.id, note.title, note.plainText);
      AppLogger.i(
        'NoteRepository: upsertNote(${note.id}) ${note.updatedAt} ${note.title} saved to $savedFileName ✓',
      );
    } on DbFullException {
      rethrow;
    } on FileSystemException catch (e) {
      AppLogger.e('NoteRepository: upsertNote failed due to storage error: $e');
      throw DbFullException('Storage is full: $e', 1018);
    } catch (e) {
      AppLogger.e('NoteRepository: upsertNote failed: $e');
      rethrow;
    }
  }

  @override
  Future<List<NoteMetaData>> searchNotes(String query) async {
    try {
      await ensureStoreConnected();
      final ids = await _indexingService.search(query);
      if (ids.isEmpty) return [];

      final queryBuilder = box.query(NoteModel_.id.oneOf(ids));
      final q = queryBuilder.build();
      final dbNotes = q.find();
      q.close();

      final notesMap = {for (var note in dbNotes) note.id: note};
      final matchingNotes = <NoteMetaData>[];
      for (final id in ids) {
        final note = notesMap[id];
        if (note != null) {
          matchingNotes.add(
            NoteMetaData(
              id: note.id,
              height: note.height,
              title: note.title,
              createdAt: note.createdAt,
              updatedAt: note.updatedAt,
              previewText: note.previewText,
              isPinned: note.isPinned,
            ),
          );
        }
      }
      AppLogger.i(
        "Found ${matchingNotes.length} matching notes via IndexingService",
      );
      return matchingNotes;
    } catch (e) {
      AppLogger.e('Failed to search notes: $e');
      return [];
    }
  }

  @override
  Future<bool> togglePinNote(String id) async {
    try {
      await ensureStoreConnected();
      final query = box.query(NoteModel_.id.equals(id)).build();
      final note = query.findFirst();
      query.close();

      if (note != null) {
        note.isPinned = !note.isPinned;
        box.put(note);
        AppLogger.i('NoteRepository: togglePinNote($id) → ${note.isPinned}');
        return note.isPinned;
      }
      return false;
    } catch (e) {
      AppLogger.e('NoteRepository: togglePinNote failed: $e');
      return false;
    }
  }

  @override
  Future<DateTime?> getNoteFileLastModified(String id) async {
    try {
      await ensureStoreConnected();
      final query = box.query(NoteModel_.id.equals(id)).build();
      final note = query.findFirst();
      query.close();
      if (note == null) return null;

      final fileToRead = note.fileName;
      if (fileToRead != null && fileToRead.isNotEmpty) {
        final lastModified = await _fileStorage.getFileLastModified(fileToRead);
        if (lastModified != null) return lastModified;
      }

      // Fallback: check by title
      final titleFileName =
          '${NoteFileStorage.sanitizeFileName(note.title)}.md';
      return await _fileStorage.getFileLastModified(titleFileName);
    } catch (e) {
      AppLogger.e('NoteRepository: getNoteFileLastModified failed for $id: $e');
      return null;
    }
  }

  @override
  Stream<void> get onDirectoryChanged => _directoryChangedController.stream;

  @override
  Future<void> reconcileWithDisk() async {
    try {
      await ensureStoreConnected();
      final dir = _fileStorage.directory;
      if (!await dir.exists()) return;

      final entities = await dir.list().toList();
      final diskMdFiles = <File>[];
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.md')) {
          final baseName = p.basename(entity.path);
          if (!baseName.startsWith('..tmp_')) {
            diskMdFiles.add(entity);
          }
        }
      }

      final existingNotes = box.getAll();
      final matchedNoteIds = <String>{};

      for (final file in diskMdFiles) {
        final fileName = p.basename(file.path);
        final content = await file.readAsString();
        final tagId = NoteTagHelper.extractId(content);

        final cleanContent = NoteTagHelper.stripTag(content);
        final lines = cleanContent
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        final firstLineTitle = lines.isNotEmpty
            ? lines.first.replaceAll(RegExp(r'^#+\s*'), '').trim()
            : p.withoutExtension(fileName);
        final plainText = markdownToPlainText(cleanContent).trim();
        final previewText = lines.length > 1
            ? lines.skip(1).join(' ')
            : plainText;
        final truncatedPreview =
            previewText.length > Constants.notePreviewTextMaxLength
                ? previewText.substring(0, Constants.notePreviewTextMaxLength)
                : previewText;
        final lastModified = await file.lastModified();

        if (tagId != null) {
          matchedNoteIds.add(tagId);
          final query = box.query(NoteModel_.id.equals(tagId)).build();
          final note = query.findFirst();
          query.close();

          if (note != null) {
            // Check if anything changed on disk compared to ObjectBox
            if (note.fileName != fileName ||
                note.content != cleanContent ||
                note.title != firstLineTitle) {
              note.fileName = fileName;
              note.title = firstLineTitle;
              note.content = cleanContent;
              note.plainText = plainText;
              note.previewText = truncatedPreview;
              note.updatedAt = lastModified;
              box.put(note);
              await _indexingService.upsertNote(
                note.id,
                note.title,
                note.plainText,
              );
              AppLogger.i(
                'NoteRepository: Updated note from disk $tagId ($fileName)',
              );
            }
          } else {
            // Tag exists on file, but note not in DB -> adopt it!
            final newNote = NoteModel(
              id: tagId,
              title: firstLineTitle,
              content: cleanContent,
              plainText: plainText,
              previewText: truncatedPreview,
              height: estimateNoteHeight(plainText),
              createdAt: lastModified,
              updatedAt: lastModified,
              fileName: fileName,
            );
            box.put(newNote);
            await _indexingService.upsertNote(
              newNote.id,
              newNote.title,
              newNote.plainText,
            );
            AppLogger.i(
              'NoteRepository: Adopted external tagged note $tagId ($fileName)',
            );
          }
        } else {
          // File has no mechanix tag: adopt it and append tag!
          final newId = const Uuid().v4();
          matchedNoteIds.add(newId);

          // Append tag to the file
          final taggedContent = NoteTagHelper.appendTag(cleanContent, newId);
          _fileStorage.markInternalWrite(fileName);
          await file.writeAsString(taggedContent, flush: true);

          final newNote = NoteModel(
            id: newId,
            title: firstLineTitle,
            content: cleanContent,
            plainText: plainText,
            previewText: truncatedPreview,
            height: estimateNoteHeight(plainText),
            createdAt: lastModified,
            updatedAt: lastModified,
            fileName: fileName,
          );
          box.put(newNote);
          await _indexingService.upsertNote(
            newNote.id,
            newNote.title,
            newNote.plainText,
          );
          AppLogger.i(
            'NoteRepository: Adopted new external note $newId ($fileName)',
          );
        }
      }

      // Check for deleted notes in ObjectBox whose files are no longer on disk
      for (final note in existingNotes) {
        if (!matchedNoteIds.contains(note.id)) {
          final fileExists = note.fileName != null &&
              await _fileStorage.noteFileExists(note.fileName!);
          if (!fileExists) {
            box.remove(note.obxId);
            await _indexingService.deleteNotesBatch([note.id]);
            AppLogger.i(
              'NoteRepository: Removed deleted external note ${note.id} (${note.title})',
            );
          }
        }
      }
    } catch (e) {
      AppLogger.e('NoteRepository: reconcileWithDisk failed: $e');
    }
  }

  void dispose() {
    _directoryWatcher?.dispose();
    _directoryChangedController.close();
  }
}
