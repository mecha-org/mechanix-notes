import 'dart:async';
import 'dart:io';

import 'package:flutter_tantivy/flutter_tantivy.dart' as tantivy;
import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/core/utils/helper.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:mechanix_notes/features/notes/data/services/indexing_service.dart';
import 'package:mechanix_notes/features/notes/data/services/note_file_storage.dart';
import 'package:mechanix_notes/features/notes/data/services/notes_watcher.dart';

class NoteRepositoryImpl extends NoteRepository {
  final IndexingService _indexingService;
  final NoteFileStorage _fileStorage;
  final NotesWatcher _notesWatcher;

  StreamSubscription<NotesWatcherEvent>? _watcherSub;
  Future<void> _watcherQueue = Future.value();

  /// Fires whenever notes are created, updated, deleted or re-synced, so
  /// [watchNotes] can re-emit. Shared by all instances, because they all
  /// read and write the same Tantivy index.
  static final StreamController<void> _changes =
      StreamController<void>.broadcast();

  /// Fires when a note file is renamed by the app or externally. Shared by
  /// all instances for the same reason as [_changes].
  static final StreamController<NoteRenamed> _renames =
      StreamController<NoteRenamed>.broadcast();

  @override
  Stream<NoteRenamed> get noteRenames => _renames.stream;

  NoteRepositoryImpl({
    IndexingService? indexingService,
    NoteFileStorage? fileStorage,
    NotesWatcher? notesWatcher,
  }) : _indexingService = indexingService ?? IndexingService(),
       _fileStorage = fileStorage ?? NoteFileStorage(),
       _notesWatcher =
           notesWatcher ??
           NotesWatcher(
             notesDirectory: (fileStorage ?? NoteFileStorage()).directory,
           );

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

    _startWatcher();
  }

  static (bool isPinned, DateTime createdAt) _indexedState(
    tantivy.Document? doc,
    DateTime fallbackCreatedAt,
  ) {
    if (doc == null) return (false, fallbackCreatedAt);
    return (
      doc.isPinned,
      DateTime.fromMillisecondsSinceEpoch(doc.createdAt.toInt()),
    );
  }

  void _startWatcher() {
    if (_watcherSub != null) return;
    _watcherSub = _notesWatcher.events.listen((event) {
      _watcherQueue = _watcherQueue.then((_) => _handleWatcherEvent(event)).catchError((e) {
        AppLogger.e('NoteRepository: Error in watcher event queue: $e');
      });
    });
    unawaited(_notesWatcher.start());
  }

  Future<void> _handleWatcherEvent(NotesWatcherEvent event) async {
    try {
      AppLogger.i('NoteRepository: Handling watcher event $event');
      switch (event.type) {
        case NotesWatcherEventType.create:
        case NotesWatcherEventType.modify:
          final file = File(event.fullPath);
          if (!await file.exists()) return;
          final stat = await file.stat();
          final rawContent = await file.readAsString();

          final fallbackTitle = event.fileName.endsWith('.md')
              ? event.fileName.substring(0, event.fileName.length - 3)
              : event.fileName;
          final (title, previewText) = _extractTitleAndPreview(
            rawContent,
            fallbackTitle,
          );

          final (isPinned, createdAt) = _indexedState(
            _indexingService.getDocument(event.fileName),
            stat.modified,
          );

          final note = NoteModel(
            id: event.fileName,
            title: title,
            content: rawContent,
            previewText: previewText,
            fileName: event.fileName,
            isPinned: isPinned,
            createdAt: createdAt,
            updatedAt: stat.modified,
          );

          await _indexingService.upsertNote(note);
          _notifyChanged();

        case NotesWatcherEventType.delete:
          await _indexingService.deleteNotesBatch([event.fileName]);
          _notifyChanged();

        case NotesWatcherEventType.move:
          final oldName = event.oldFileName;
          final newName = event.fileName;
          final priorDoc =
              (oldName != null
                  ? _indexingService.getDocument(oldName)
                  : null) ??
              _indexingService.getDocument(newName);
          if (oldName != null) {
            await _indexingService.deleteNotesBatch([oldName]);
          }

          final file = File(event.fullPath);
          if (await file.exists()) {
            final stat = await file.stat();
            final rawContent = await file.readAsString();
            final fallbackTitle = newName.endsWith('.md')
                ? newName.substring(0, newName.length - 3)
                : newName;
            final (title, previewText) = _extractTitleAndPreview(
              rawContent,
              fallbackTitle,
            );

            final (isPinned, createdAt) = _indexedState(
              priorDoc,
              stat.modified,
            );

            final note = NoteModel(
              id: newName,
              title: title,
              content: rawContent,
              previewText: previewText,
              fileName: newName,
              isPinned: isPinned,
              createdAt: createdAt,
              updatedAt: stat.modified,
            );
            await _indexingService.upsertNote(note);
          }
          if (oldName != null && oldName != newName) {
            _renames.add(NoteRenamed(oldId: oldName, newId: newName));
          }
          _notifyChanged();
      }
    } catch (e) {
      AppLogger.e('NoteRepository: Error handling watcher event: $e');
    }
  }

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

      // 1. Try reading from disk by fileName directly, doc.fileName, or id
      String? fileName;
      String? markdown;

      final candidates = <String>[
        if (doc?.fileName != null && doc!.fileName!.isNotEmpty) doc.fileName!,
        if (id.endsWith('.md')) id,
        '$id.md',
        id,
      ];

      for (final candidate in candidates) {
        if (await _fileStorage.noteFileExists(candidate)) {
          markdown = await _fileStorage.readNoteContent(candidate);
          fileName = candidate;
          break;
        }
      }

      // 2. Fallback: try resolving by title (e.g. if saved under title directly)
      if (markdown == null && doc != null) {
        final titleFileName =
            '${NoteFileStorage.sanitizeFileName(doc.title)}.md';
        if (await _fileStorage.noteFileExists(titleFileName)) {
          markdown = await _fileStorage.readNoteContent(titleFileName);
          if (markdown != null) {
            fileName = titleFileName;
          }
        }
      }

      // If no file exists on disk:
      if (markdown == null) {
        if (doc != null && doc.fileName == null) {
          // Document exists in index without a file on disk (e.g. mocked in unit test)
          final (isPinned, createdAt) = _indexedState(doc, DateTime.now());
          return NoteModel(
            id: doc.id,
            title: doc.title,
            content: '',
            previewText: doc.previewText,
            fileName: doc.fileName,
            isPinned: isPinned,
            createdAt: createdAt,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
              doc.updatedAt.toInt(),
            ),
          );
        }

        if (doc != null && doc.fileName != null) {
          // File confirmed missing from disk -> purge ghost note from Tantivy on access
          AppLogger.i(
            'NoteRepository: Note $id (${doc.fileName}) missing on disk. Purging ghost note from Tantivy...',
          );
          unawaited(
            _indexingService
                .deleteNotesBatch([id])
                .then((_) => _notifyChanged())
                .catchError((e) {
                  AppLogger.e('NoteRepository: Purging ghost note failed: $e');
                }),
          );
        }
        AppLogger.i('NoteRepository: getNoteById($id) → not found');
        return null;
      }

      fileName ??= (id.endsWith('.md') ? id : '$id.md');
      final fileModified =
          (await _fileStorage.getFileLastModified(fileName)) ?? DateTime.now();

      final title =
          doc?.title ??
          (fileName.endsWith('.md')
              ? fileName.substring(0, fileName.length - 3)
              : fileName);
      final (isPinned, createdAt) = _indexedState(doc, fileModified);

      final note = NoteModel(
        id: doc?.id ?? fileName,
        title: title,
        content: markdown,
        previewText: doc?.previewText ?? '',
        fileName: fileName,
        isPinned: isPinned,
        createdAt: createdAt,
        updatedAt: fileModified,
      );

      AppLogger.i('NoteRepository: getNoteById($id) → found');
      return note;
    } catch (e) {
      AppLogger.e('NoteRepository: getNoteById failed: $e');
      return null;
    }
  }

  @override
  Future<void> deleteNotes(List<String> ids) async {
    try {
      await ensureStoreConnected();

      for (final id in ids) {
        final doc = _indexingService.getDocument(id);
        final fileNames = <String>{
          id,
          if (id.endsWith('.md')) id else '$id.md',
          if (doc?.fileName != null && doc!.fileName!.isNotEmpty) doc.fileName!,
        };

        for (final fn in fileNames) {
          await _fileStorage.deleteNoteFile(fn);
        }
      }

      await _indexingService.deleteNotesBatch(ids);
      _notifyChanged();
      AppLogger.i('NoteRepository: deleteNotes(${ids.length})');
    } catch (e) {
      AppLogger.e('NoteRepository: deleteNotes failed: $e');
    }
  }

  @override
  Future<String> upsertNote(NoteModel note) async {
    try {
      await ensureStoreConnected();

      final markdown = note.content;
      final fileMarkdown = markdown.isEmpty
          ? ''
          : (markdown.endsWith('\n') ? markdown : '$markdown\n');

      final previousFileName = note.fileName;
      final isNew = previousFileName == null || previousFileName.isEmpty;

      // Throws NoteFileMissingException if the existing file is gone; the
      // caller decides whether to re-create it.
      final savedFileName = isNew
          ? await _fileStorage.createNoteFile(
              title: note.title,
              markdown: fileMarkdown,
            )
          : await _fileStorage.updateNoteFile(
              fileName: previousFileName,
              title: note.title,
              markdown: fileMarkdown,
            );

      final isRename = !isNew && previousFileName != savedFileName;
      if (isRename) {
        await _indexingService.deleteNotesBatch(
          {previousFileName, note.id}.toList(),
        );
      }

      note.id = savedFileName;
      note.fileName = savedFileName;
      note.content = markdown;

      await _indexingService.upsertNote(note);
      if (isRename) {
        _renames.add(
          NoteRenamed(oldId: previousFileName, newId: savedFileName),
        );
      }
      _notifyChanged();
      AppLogger.i(
        'NoteRepository: upsertNote($savedFileName) ${note.updatedAt} ${note.title} saved ✓',
      );
      return savedFileName;
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
      final results = await _indexingService.search(query);
      return results.map((n) => n.id).toList();
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
      // Keep the caller's order (search relevance)
      return [for (final id in ids) ?_indexingService.getNoteMetaData(id)];
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
      _notifyChanged();
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

  @override
  Stream<List<NoteMetaData>> watchNotes() {
    late final StreamController<List<NoteMetaData>> controller;
    StreamSubscription<void>? changesSub;

    controller = StreamController<List<NoteMetaData>>(
      onListen: () async {
        try {
          await _fileStorage.ensureDirectoryExists();
        } catch (e) {
          AppLogger.e('Failed to initialize note file directory: $e');
        }

        try {
          await _indexingService.initialize();
        } catch (e, s) {
          if (!controller.isClosed) {
            controller.addError(e, s);
            await controller.close();
          }
          return;
        }

        _startWatcher();

        bool hasPendingChange = false;
        bool isReading = false;

        Future<void> readAndEmit() async {
          if (isReading) {
            hasPendingChange = true;
            return;
          }
          isReading = true;
          try {
            do {
              hasPendingChange = false;
              final notes = await _getAllNotes();
              if (!controller.isClosed) {
                controller.add(notes);
              }
            } while (hasPendingChange && !controller.isClosed);
          } catch (e, s) {
            if (!controller.isClosed) {
              controller.addError(e, s);
            }
          } finally {
            isReading = false;
          }
        }

        // Subscribe before the first read so no change is missed in between
        changesSub = _changes.stream.listen((_) {
          unawaited(readAndEmit());
        });

        await readAndEmit();
      },
      onCancel: () async {
        await changesSub?.cancel();
        changesSub = null;
      },
    );

    return controller.stream;
  }

  /// Fetches every note metadata item by paging through Tantivy in chunks of 50.
  Future<List<NoteMetaData>> _getAllNotes() async {
    final allNotes = <NoteMetaData>[];
    const pageSize = 50;
    while (true) {
      final page = await _indexingService.getNotes(
        skip: allNotes.length,
        take: pageSize,
      );
      allNotes.addAll(page);
      if (page.length < pageSize) break;
    }
    return allNotes;
  }

  void _notifyChanged() {
    _changes.add(null);
  }

  static (String title, String previewText) _extractTitleAndPreview(
    String markdown,
    String defaultTitle,
  ) {
    return extractTitleAndPreviewFromMarkdown(
      markdown,
      fallbackTitle: defaultTitle,
    );
  }

  @override
  Future<int> syncNotesFromDisk() async {
    try {
      await ensureStoreConnected();
      final dir = _fileStorage.directory;
      if (!await dir.exists()) return 0;

      int updatedCount = 0;
      // Snapshot the index BEFORE listing files on disk so notes saved
      // concurrently while listing are never falsely flagged as ghosts.
      final indexedDocs = await _indexingService.getAllDocuments();
      final docsById = {for (final d in indexedDocs) d.id: d};
      final docsByFileName = <String, tantivy.Document>{
        for (final d in indexedDocs)
          if (d.fileName != null && d.fileName!.isNotEmpty) d.fileName!: d,
      };

      final entities = await dir.list().toList();
      final discoveredNoteIds = <String>{};
      final notesToUpsert = <NoteModel>[];

      for (final entity in entities) {
        if (entity is! File || !NotesWatcher.isTrackedFile(entity.path)) {
          continue;
        }
        final fileName = entity.uri.pathSegments.last;
        discoveredNoteIds.add(fileName);

        try {
          final fileStat = await entity.stat();
          final existingDoc = docsById[fileName] ?? docsByFileName[fileName];

          final indexedUpdatedAt = existingDoc != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  existingDoc.updatedAt.toInt(),
                )
              : null;

          // Re-index if missing from Tantivy, using legacy ID, or modified externally
          final needsReindex =
              existingDoc == null ||
              existingDoc.id != fileName ||
              fileStat.modified.isAfter(
                indexedUpdatedAt!.add(const Duration(seconds: 1)),
              );

          if (needsReindex) {
            final rawContent = await entity.readAsString();
            final fallbackTitle = fileName.endsWith('.md')
                ? fileName.substring(0, fileName.length - 3)
                : fileName;
            final (title, previewText) = _extractTitleAndPreview(
              rawContent,
              existingDoc?.title ?? fallbackTitle,
            );

            final (isPinned, createdAt) = _indexedState(
              existingDoc,
              fileStat.modified,
            );

            final note = NoteModel(
              id: fileName,
              title: title,
              content: rawContent,
              previewText: previewText,
              fileName: fileName,
              createdAt: createdAt,
              updatedAt: fileStat.modified,
              isPinned: isPinned,
            );

            notesToUpsert.add(note);
            AppLogger.i(
              'NoteRepository: Reconciled $fileName for Tantivy indexing',
            );
          }
        } catch (e) {
          AppLogger.e('NoteRepository: Failed to sync $fileName: $e');
        }
      }

      if (notesToUpsert.length == 1) {
        await _indexingService.upsertNote(notesToUpsert.first);
        updatedCount += 1;
      } else if (notesToUpsert.length > 1) {
        await _indexingService.upsertNotesBatch(notesToUpsert);
        updatedCount += notesToUpsert.length;
      }

      // Purge ghost notes from Tantivy whose files were deleted on disk
      try {
        final ghostIds = docsById.keys
            .where((id) => !discoveredNoteIds.contains(id))
            .toList();
        if (ghostIds.isNotEmpty) {
          await _indexingService.deleteNotesBatch(ghostIds);
          updatedCount += ghostIds.length;
          AppLogger.i(
            'NoteRepository: Purged ${ghostIds.length} ghost notes from Tantivy',
          );
        }
      } catch (e) {
        AppLogger.e('NoteRepository: Failed to purge ghost notes: $e');
      }

      if (updatedCount > 0) _notifyChanged();
      return updatedCount;
    } catch (e) {
      AppLogger.e('NoteRepository: syncNotesFromDisk failed: $e');
      return 0;
    }
  }

  @override
  Future<void> close() async {
    await _watcherSub?.cancel();
    _watcherSub = null;
    await _watcherQueue;
    await _notesWatcher.dispose();
  }
}
