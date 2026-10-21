import 'dart:io';

import 'package:flutter_tantivy/flutter_tantivy.dart' as tantivy;
import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/core/utils/constants.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';

class IndexingService {
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await tantivy.RustLib.init();
      final home = Platform.environment['HOME'];
      final indexDir = Directory('$home${Constants.notesTantivyDbPath}');
      AppLogger.d('[IndexingService] Init: ${indexDir.path}');
      if (!await indexDir.exists()) {
        await indexDir.create(recursive: true);
      }
      tantivy.initTantivy(dirPath: indexDir.path);
      _initialized = true;
      AppLogger.d('[IndexingService] Ready');
    } catch (e) {
      AppLogger.e('[IndexingService] Init failed: $e');
      rethrow;
    }
  }

  /// Limits content to the maximum characters and words allowed for indexing.
  static String truncateContent(String plainText) {
    String truncatedPlainText = plainText;
    if (truncatedPlainText.length > Constants.tantivyIndexContentMaxLength) {
      truncatedPlainText = truncatedPlainText.substring(
        0,
        Constants.tantivyIndexContentMaxLength,
      );
      AppLogger.d(
        '[IndexingService] Char limit: ${plainText.length} -> ${truncatedPlainText.length}',
      );
    }
    final wordMatches = RegExp(r'\S+').allMatches(truncatedPlainText);
    if (wordMatches.length > Constants.tantivyIndexContentMaxWords) {
      final endOfMaxWords = wordMatches
          .elementAt(Constants.tantivyIndexContentMaxWords - 1)
          .end;
      truncatedPlainText = truncatedPlainText.substring(0, endOfMaxWords);
      AppLogger.d(
        '[IndexingService] Word limit: ${wordMatches.length} -> ${Constants.tantivyIndexContentMaxWords}',
      );
    }
    return truncatedPlainText;
  }

  NoteMetaData docToMetaData(tantivy.Document doc) {
    return NoteMetaData(
      id: doc.id,
      title: doc.title,
      previewText: doc.previewText,
      createdAt: DateTime.fromMillisecondsSinceEpoch(doc.createdAt.toInt()),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(doc.updatedAt.toInt()),
      height: 60.0,
      isPinned: doc.isPinned,
    );
  }

  tantivy.Document noteModelToDoc(NoteModel note) {
    final truncatedContent = truncateContent(note.content);
    return tantivy.Document(
      id: note.id,
      title: note.title,
      content: truncatedContent,
      previewText: note.previewText,
      fileName: note.fileName,
      isPinned: note.isPinned,
      createdAt: tantivy.PlatformInt64Util.from(
        note.createdAt.millisecondsSinceEpoch,
      ),
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

      return results.map((r) => docToMetaData(r.doc)).toList();
    } catch (e) {
      AppLogger.e('[IndexingService] Search failed ($query): $e');
      return [];
    }
  }

  /// Fetches raw documents stored directly in Tantivy index.
  Future<List<tantivy.Document>> getStoredDocuments({int limit = 45}) async {
    try {
      if (!_initialized) {
        await initialize();
      }
      final docs = await tantivy.getNotes(
        skip: BigInt.zero,
        take: BigInt.from(limit),
      );
      return docs;
    } catch (e) {
      AppLogger.e('[IndexingService] getStoredDocuments failed: $e');
      return [];
    }
  }
}
