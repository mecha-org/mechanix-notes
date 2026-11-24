import 'dart:io';

import 'package:flutter_tantivy/flutter_tantivy.dart' as tantivy;
import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/core/utils/constants.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';

class IndexingService {
  static const int currentSchemaVersion = 5;
  Future<void>? _initFuture;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() {
    if (_initialized) return Future.value();
    return _initFuture ??= _doInitialize().catchError((Object e, StackTrace s) {
      _initFuture = null;
      Error.throwWithStackTrace(e, s);
    });
  }

  Future<void> _doInitialize() async {
    try {
      // ignore: invalid_use_of_internal_member
      if (!tantivy.RustLib.instance.initialized) {
        await tantivy.RustLib.init();
      }
      final home = Platform.environment['HOME'];
      final indexDir = Directory('$home${Constants.notesTantivyDbPath}');
      AppLogger.d('[IndexingService] Init: ${indexDir.path}');
      if (!await indexDir.exists()) {
        await indexDir.create(recursive: true);
      }

      final versionFile = File('${indexDir.path}/version.txt');
      var needsFresh = false;
      if (await versionFile.exists()) {
        final versionStr = (await versionFile.readAsString()).trim();
        if (int.tryParse(versionStr) != currentSchemaVersion) {
          needsFresh = true;
        }
      } else if (await indexDir.exists()) {
        final count = await indexDir.list().length;
        if (count > 0) {
          needsFresh = true;
        }
      }

      if (needsFresh) {
        AppLogger.i(
          '[IndexingService] Schema version change detected. Recreating fresh index (v$currentSchemaVersion)...',
        );
        if (await indexDir.exists()) {
          await indexDir.delete(recursive: true);
          await indexDir.create(recursive: true);
        }
      }

      try {
        tantivy.initTantivy(dirPath: indexDir.path);
      } catch (e) {
        AppLogger.e(
          '[IndexingService] Tantivy init failed (corrupted index or missing meta.json): $e. Recreating fresh index...',
        );
        if (await indexDir.exists()) {
          await indexDir.delete(recursive: true);
          await indexDir.create(recursive: true);
        }
        tantivy.initTantivy(dirPath: indexDir.path);
      }

      await versionFile.writeAsString('$currentSchemaVersion');
      _initialized = true;
      AppLogger.d('[IndexingService] Ready (v$currentSchemaVersion)');
    } catch (e) {
      AppLogger.e('[IndexingService] Init failed: $e');
      rethrow;
    }
  }

  NoteMetaData docToMetaData(tantivy.Document doc, {String? snippet}) {
    return NoteMetaData(
      id: doc.id,
      title: doc.title,
      previewText: doc.previewText,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(doc.updatedAt.toInt()),
      isPinned: doc.isPinned,
      snippet: snippet,
    );
  }

  /// The list entry for [note], built locally so a save never needs to read
  /// the index back. Static (pure conversion), so it also works when the
  /// service is mocked.
  static NoteMetaData noteModelToMetaData(NoteModel note) {
    return NoteMetaData(
      id: note.id,
      title: note.title,
      previewText: note.previewText,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        note.updatedAt.millisecondsSinceEpoch,
      ),
      isPinned: note.isPinned,
    );
  }

  tantivy.Document noteModelToDoc(NoteModel note) {
    return tantivy.Document(
      id: note.id,
      title: note.title,
      content: note.content,
      previewText: note.previewText,
      isPinned: note.isPinned,
      updatedAt: tantivy.PlatformInt64Util.from(
        note.updatedAt.millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> upsertNote(NoteModel note) async {
    try {
      if (!_initialized) {
        await initialize();
      }
      AppLogger.d('[IndexingService] Upsert: id=${note.id}');
      await tantivy.updateDocument(doc: noteModelToDoc(note));
    } catch (e) {
      AppLogger.e('[IndexingService] Upsert failed (${note.id}): $e');
      rethrow;
    }
  }

  Future<void> upsertNotesBatch(List<NoteModel> notes) async {
    if (notes.isEmpty) return;
    try {
      if (!_initialized) {
        await initialize();
      }
      AppLogger.d('[IndexingService] Batch upsert: ${notes.length} notes');
      final docs = notes.map(noteModelToDoc).toList();
      await tantivy.addDocumentsBatch(docs: docs);
    } catch (e) {
      AppLogger.e('[IndexingService] Batch upsert failed: $e');
      rethrow;
    }
  }

  Future<void> deleteNotesBatch(List<String> ids) async {
    try {
      if (!_initialized) {
        await initialize();
      }
      AppLogger.d('[IndexingService] Delete: $ids');
      await tantivy.deleteDocumentsBatch(ids: ids);
    } catch (e) {
      AppLogger.e('[IndexingService] Delete failed: $e');
    }
  }

  Future<List<NoteMetaData>> getNotes({
    required int skip,
    required int take,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }
      final docs = await tantivy.getNotes(
        skip: BigInt.from(skip),
        take: BigInt.from(take),
      );
      return docs.map(docToMetaData).toList();
    } catch (e) {
      AppLogger.e('[IndexingService] getNotes failed: $e');
      return [];
    }
  }

  tantivy.Document? getDocument(String id) {
    if (!_initialized) return null;
    try {
      return tantivy.getDocumentById(id: id);
    } catch (e) {
      AppLogger.e('[IndexingService] getDocument failed ($id): $e');
      return null;
    }
  }

  NoteMetaData? getNoteMetaData(String id) {
    final doc = getDocument(id);
    if (doc == null) return null;
    return docToMetaData(doc);
  }

  String? getTitleById(String id) {
    final doc = getDocument(id);
    if (doc != null && doc.title.isNotEmpty) {
      return doc.title;
    }
    return null;
  }

  Future<bool> togglePin(String id) async {
    try {
      if (!_initialized) {
        await initialize();
      }
      return await tantivy.togglePinDocument(id: id);
    } catch (e) {
      AppLogger.e('[IndexingService] togglePin failed ($id): $e');
      return false;
    }
  }

  /// Performs a full-text search against the Tantivy index, returning matching NoteMetaData in order of relevance.
  Future<List<NoteMetaData>> search(
    String query, {
    int limit = Constants.searchResultLimit,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }
      final cleanQuery = query.trim();
      if (cleanQuery.isEmpty) return [];

      final results = await tantivy.searchDocuments(
        query: cleanQuery,
        topK: BigInt.from(limit),
      );

      AppLogger.d(
        '[IndexingService] Search: "$cleanQuery" -> ${results.length}',
      );

      return results
          .map((r) => docToMetaData(r.doc, snippet: r.snippet))
          .toList();
    } catch (e) {
      AppLogger.e('[IndexingService] Search failed ($query): $e');
      return [];
    }
  }

  /// Fetches every indexed note, in pages.
  Future<List<tantivy.Document>> getAllMetadata({int batchSize = 500}) async {
    if (!_initialized) {
      await initialize();
    }
    final all = <tantivy.Document>[];
    while (true) {
      final batch = await tantivy.getNotes(
        skip: BigInt.from(all.length),
        take: BigInt.from(batchSize),
      );
      all.addAll(batch);
      if (batch.length < batchSize) return all;
    }
  }
}
