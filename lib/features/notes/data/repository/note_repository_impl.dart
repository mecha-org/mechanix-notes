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

/// What changed in the index, so [NoteRepositoryImpl.watchNotes] can patch
/// its in-memory list instead of re-reading every note on each save.
sealed class _NoteChange {}

final class _NoteUpserted extends _NoteChange {
  final NoteMetaData meta;

  /// Ids this entry replaces (old filename on rename, temporary id on first
  /// save). Part of the same change so the list never shows the note missing.
  final Set<String> replaces;

  _NoteUpserted(this.meta, {this.replaces = const {}});
}

final class _NoteRemoved extends _NoteChange {
  final Set<String> ids;
  _NoteRemoved(this.ids);
}

/// Many notes may have changed (disk sync, index rebuild): reload everything.
final class _NotesReset extends _NoteChange {}

class NoteRepositoryImpl extends NoteRepository {
  final IndexingService _indexingService;
  final NoteFileStorage _fileStorage;
  final NotesWatcher _notesWatcher;

  StreamSubscription<NotesWatcherEvent>? _watcherSub;
  Future<void> _watcherQueue = Future.value();

  /// Describes every create, update, delete or re-sync, so [watchNotes] can
  /// update its list incrementally. Shared by all instances, because they all
  /// read and write the same Tantivy index.
  static final StreamController<_NoteChange> _changes =
      StreamController<_NoteChange>.broadcast();

  /// Metadata from the last search, so paging through results does not hit
  /// the index once per id.
  Map<String, NoteMetaData> _searchMeta = const {};

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

  /// Pin status and creation time from an indexed entry ([tantivy.Document]
  /// or [tantivy.NoteMeta]); unpinned and [fallbackCreatedAt] if not indexed.
  static (bool isPinned, DateTime createdAt) _indexedState(
    bool? isPinned,
    tantivy.PlatformInt64? createdAt,
    DateTime fallbackCreatedAt,
  ) {
    if (isPinned == null || createdAt == null) {
      return (false, fallbackCreatedAt);
    }
    return (isPinned, DateTime.fromMillisecondsSinceEpoch(createdAt.toInt()));
  }

  void _startWatcher() {
    if (_watcherSub != null) return;
    _watcherSub = _notesWatcher.events.listen((event) {
      _watcherQueue = _watcherQueue
          .then((_) => _handleWatcherEvent(event))
          .catchError((e) {
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

          final existing = _indexingService.getDocument(event.fileName);
          final (isPinned, createdAt) = _indexedState(
            existing?.isPinned,
            existing?.createdAt,
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
          _notifyUpserted(note);

        case NotesWatcherEventType.delete:
          await _indexingService.deleteNotesBatch([event.fileName]);
          _notifyRemoved([event.fileName]);

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
              priorDoc?.isPinned,
              priorDoc?.createdAt,
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
            _notifyUpserted(note, replaces: [?oldName]);
          } else if (oldName != null) {
            _notifyRemoved([oldName]);
          }
          if (oldName != null && oldName != newName) {
            _renames.add(NoteRenamed(oldId: oldName, newId: newName));
          }
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
          final (isPinned, createdAt) = _indexedState(
            doc.isPinned,
            doc.createdAt,
            DateTime.now(),
          );
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
                .then((_) => _notifyRemoved([id]))
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
      final (isPinned, createdAt) = _indexedState(
        doc?.isPinned,
        doc?.createdAt,
        fileModified,
      );

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

      final removed = <String>{...ids};
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
        removed.addAll(fileNames);
      }

      await _indexingService.deleteNotesBatch(ids);
      _notifyRemoved(removed);
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
      final previousId = note.id;
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
      // The saved note takes the place of a new note's temporary id or a
      // renamed note's old filename.
      _notifyUpserted(
        note,
        replaces: {previousId, if (isRename) previousFileName},
      );
      if (isRename) {
        _renames.add(
          NoteRenamed(oldId: previousFileName, newId: savedFileName),
        );
      }
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
      _searchMeta = {for (final n in results) n.id: n};
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
      // Keep the caller's order (search relevance). Results from the last
      // search already carry their metadata; only fall back to the index for
      // ids that did not come from it.
      return [
        for (final id in ids)
          ?(_searchMeta[id] ?? _indexingService.getNoteMetaData(id)),
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
      final meta = _indexingService.getNoteMetaData(id);
      if (meta != null) {
        _changes.add(_NoteUpserted(meta));
      } else {
        _changes.add(_NotesReset());
      }
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
    StreamSubscription<_NoteChange>? changesSub;
    var cancelled = false;

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
        // Cancelled while initializing: don't subscribe to anything.
        if (cancelled) return;

        _startWatcher();

        // The list is read from the index once, then kept up to date from
        // the change events; only a reset (disk sync) reads it again.
        final cache = <String, NoteMetaData>{};
        final pending = <_NoteChange>[];
        var loaded = false;
        var reloading = false;
        var reloadAgain = false;
        var emitScheduled = false;

        void apply(_NoteChange change) {
          switch (change) {
            case _NoteUpserted(:final meta, :final replaces):
              replaces.forEach(cache.remove);
              cache[meta.id] = meta;
            case _NoteRemoved(:final ids):
              ids.forEach(cache.remove);
            case _NotesReset():
              break;
          }
        }

        // Several changes in one burst (e.g. rename = remove + upsert)
        // produce a single emission.
        void emitSoon() {
          if (emitScheduled) return;
          emitScheduled = true;
          scheduleMicrotask(() {
            emitScheduled = false;
            if (!controller.isClosed) {
              controller.add(_sortedForList(cache.values));
            }
          });
        }

        Future<void> reload() async {
          if (reloading) {
            reloadAgain = true;
            return;
          }
          reloading = true;
          try {
            do {
              reloadAgain = false;
              loaded = false;
              final all = await _getAllNotes();
              cache
                ..clear()
                ..addEntries(all.map((m) => MapEntry(m.id, m)));
              loaded = true;
              // Changes that arrived during the read are applied on top, in
              // order, so the newest state wins.
              pending
                ..forEach(apply)
                ..clear();
            } while (reloadAgain && !controller.isClosed);
            emitSoon();
          } catch (e, s) {
            if (!controller.isClosed) controller.addError(e, s);
          } finally {
            reloading = false;
          }
        }

        // Subscribe before the first read so no change is missed in between
        changesSub = _changes.stream.listen((change) {
          if (change is _NotesReset) {
            unawaited(reload());
          } else if (!loaded) {
            pending.add(change);
          } else {
            apply(change);
            emitSoon();
          }
        });

        await reload();
      },
      onCancel: () async {
        cancelled = true;
        await changesSub?.cancel();
        changesSub = null;
      },
    );

    return controller.stream;
  }

  /// Same order as the index's `sort_key`: pinned first, then most recently
  /// updated.
  static List<NoteMetaData> _sortedForList(Iterable<NoteMetaData> notes) {
    return notes.toList()..sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  /// Reads every note's metadata from the index (no note bodies). Only used
  /// for the initial load and after a reset.
  Future<List<NoteMetaData>> _getAllNotes() async {
    final allNotes = <NoteMetaData>[];
    const pageSize = 500;
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

  void _notifyUpserted(NoteModel note, {Iterable<String> replaces = const []}) {
    _changes.add(
      _NoteUpserted(
        IndexingService.noteModelToMetaData(note),
        replaces: replaces.where((id) => id != note.id).toSet(),
      ),
    );
  }

  void _notifyRemoved(Iterable<String> ids) {
    final set = ids.toSet();
    if (set.isNotEmpty) _changes.add(_NoteRemoved(set));
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
      final indexedDocs = await _indexingService.getAllMetadata();
      final docsById = {for (final d in indexedDocs) d.id: d};
      final docsByFileName = <String, tantivy.NoteMeta>{
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

          // Re-index if missing from Tantivy, using legacy ID, modified
          // externally, or its stored title still carries Markdown markers
          // (titles indexed before H1 formatting was stripped).
          final needsReindex =
              existingDoc == null ||
              existingDoc.id != fileName ||
              fileStat.modified.isAfter(
                indexedUpdatedAt!.add(const Duration(seconds: 1)),
              ) ||
              markdownToPlainText(existingDoc.title) != existingDoc.title;

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
              existingDoc?.isPinned,
              existingDoc?.createdAt,
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

      if (updatedCount > 0) _changes.add(_NotesReset());
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
