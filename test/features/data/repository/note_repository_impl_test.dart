import 'dart:async';
import 'dart:io';

import 'package:flutter_tantivy/flutter_tantivy.dart' as tantivy;
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository_impl.dart';
import 'package:mechanix_notes/features/notes/data/services/indexing_service.dart';
import 'package:mechanix_notes/features/notes/data/services/note_file_storage.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks & Fakes
// ---------------------------------------------------------------------------

class MockIndexingService extends Mock implements IndexingService {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

NoteModel _makeNote({
  required String id,
  required String title,
  String previewText = '',
  DateTime? createdAt,
  DateTime? updatedAt,
  bool isPinned = false,
  String? fileName,
}) {
  final now = DateTime.now();
  return NoteModel(
    id: id,
    title: title,
    content: 'content',
    previewText: previewText,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    isPinned: isPinned,
    fileName: fileName,
  );
}

tantivy.Document _makeDoc({
  required String id,
  required String title,
  String content = 'content',
  String previewText = '',
  String? fileName,
  bool isPinned = false,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime.now();
  return tantivy.Document(
    id: id,
    title: title,
    content: content,
    previewText: previewText,
    fileName: fileName,
    isPinned: isPinned,
    createdAt: tantivy.PlatformInt64Util.from(
      (createdAt ?? now).millisecondsSinceEpoch,
    ),
    updatedAt: tantivy.PlatformInt64Util.from(
      (updatedAt ?? now).millisecondsSinceEpoch,
    ),
  );
}

NoteMetaData _makeMetaData({
  required String id,
  required String title,
  String previewText = '',
  double height = 200,
  DateTime? createdAt,
  DateTime? updatedAt,
  bool isPinned = false,
}) {
  final now = DateTime.now();
  return NoteMetaData(
    id: id,
    title: title,
    previewText: previewText,
    height: height,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    isPinned: isPinned,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockIndexingService mockIndexingService;
  late NoteFileStorage fileStorage;
  late Directory tempDir;
  late NoteRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(
      NoteModel(
        id: '',
        title: '',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        previewText: '',
      ),
    );
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('note_repo_impl_test_');
    fileStorage = NoteFileStorage(notesDirectory: tempDir);
    mockIndexingService = MockIndexingService();
    repository = NoteRepositoryImpl(
      indexingService: mockIndexingService,
      fileStorage: fileStorage,
    );

    // Setup default indexing stubs
    when(() => mockIndexingService.initialize()).thenAnswer((_) async {});
    when(() => mockIndexingService.upsertNote(any())).thenAnswer((_) async {});
    when(
      () => mockIndexingService.deleteNotesBatch(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockIndexingService.getNotes(
        skip: any(named: 'skip'),
        take: any(named: 'take'),
      ),
    ).thenAnswer((_) async => []);
    when(() => mockIndexingService.search(any())).thenAnswer((_) async => []);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // -------------------------------------------------------------------------
  // watchNotes
  // -------------------------------------------------------------------------

  group('getNotes', () {
    test('returns empty list when index is empty', () async {
      when(
        () => mockIndexingService.getNotes(skip: 0, take: 10),
      ).thenAnswer((_) async => []);

      final result = await repository.getNotes(0, 10);

      expect(result, isEmpty);
    });

    test('returns NoteMetaData list when index has notes', () async {
      final meta1 = _makeMetaData(id: '1', title: 'Note 1');
      final meta2 = _makeMetaData(id: '2', title: 'Note 2');

      when(
        () => mockIndexingService.getNotes(skip: 0, take: 10),
      ).thenAnswer((_) async => [meta1, meta2]);

      final result = await repository.getNotes(0, 10);

      expect(result, hasLength(2));
      expect(result.map((n) => n.id), containsAll(['1', '2']));
    });

    test('returns empty list and does not throw on exception', () async {
      when(
        () => mockIndexingService.getNotes(skip: 0, take: 10),
      ).thenThrow(Exception('Tantivy error'));

      final result = await repository.getNotes(0, 10);

      expect(result, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // getNoteById
  // -------------------------------------------------------------------------

  group('getNoteById & getNoteMetaData', () {
    test('returns metadata of single note by id correctly', () async {
      final meta = _makeMetaData(id: 'solo', title: 'Solo Note');
      when(() => mockIndexingService.getNoteMetaData('solo')).thenReturn(meta);

      final result = await repository.getNoteMetaData('solo');

      expect(result, isNotNull);
      expect(result!.id, equals('solo'));
      expect(result.title, equals('Solo Note'));
    });

    test('returns NoteModel by id correctly', () async {
      final doc = _makeDoc(id: 'solo', title: 'Solo Note');
      when(() => mockIndexingService.getDocument('solo')).thenReturn(doc);

      final result = await repository.getNoteById('solo');

      expect(result, isNotNull);
      expect(result!.id, equals('solo'));
      expect(result.title, equals('Solo Note'));
    });

    test('returns null when document not found in Tantivy', () async {
      when(() => mockIndexingService.getDocument('missing')).thenReturn(null);

      final result = await repository.getNoteById('missing');

      expect(result, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // deleteNotes & upsertNote
  // -------------------------------------------------------------------------

  group('deleteNotes & upsertNote', () {
    test('deleteNotes calls deleteNotesBatch and deletes files', () async {
      final doc1 = _makeDoc(id: '1', title: 'Note 1', fileName: 'Note 1.md');
      final doc2 = _makeDoc(id: '2', title: 'Note 2', fileName: 'Note 2.md');
      when(() => mockIndexingService.getDocument('1')).thenReturn(doc1);
      when(() => mockIndexingService.getDocument('2')).thenReturn(doc2);

      await fileStorage.writeNoteContent(
        title: 'Note 1',
        markdown: 'content 1',
      );
      await fileStorage.writeNoteContent(
        title: 'Note 2',
        markdown: 'content 2',
      );

      await repository.deleteNotes(['1', '2']);

      verify(() => mockIndexingService.deleteNotesBatch(['1', '2'])).called(1);
      expect(await fileStorage.noteFileExists('Note 1.md'), isFalse);
      expect(await fileStorage.noteFileExists('Note 2.md'), isFalse);
    });

    test(
      'upsertNote writes full markdown to .md file and updates Tantivy',
      () async {
        when(
          () => mockIndexingService.getDocument('save-test'),
        ).thenReturn(null);

        final note = _makeNote(
          id: 'save-test',
          title: 'File Test',
          previewText: 'preview',
        );
        note.content = 'My awesome note content';

        await repository.upsertNote(note);

        expect(await fileStorage.noteFileExists('File Test.md'), isTrue);
        final savedContent = await fileStorage.readNoteContent('File Test.md');
        expect(savedContent, contains('My awesome note content'));
        expect(savedContent, contains('<!-- mechanix:id=save-test -->'));

        verify(() => mockIndexingService.upsertNote(any())).called(1);
      },
    );

    test(
      'getNoteById reads full markdown from .md file using fileName and strips tag',
      () async {
        await fileStorage.writeNoteContent(
          title: 'Open Test',
          markdown: 'Body text here\n<!-- mechanix:id=open-test -->',
        );

        final doc = _makeDoc(
          id: 'open-test',
          title: 'Open Test',
          fileName: 'Open Test.md',
        );
        when(
          () => mockIndexingService.getDocument('open-test'),
        ).thenReturn(doc);

        final note = await repository.getNoteById('open-test');

        expect(note, isNotNull);
        expect(note!.content, equals('Body text here'));
        expect(note.content, isNot(contains('mechanix:id')));
      },
    );

    test(
      'getNoteById auto-heals filename when file was renamed on disk with matching embedded tag',
      () async {
        final file = File('${tempDir.path}/Renamed File.md');
        await file.writeAsString(
          '# Renamed File\n\nContent here\n<!-- mechanix:id=heal-test -->',
        );

        final doc = _makeDoc(
          id: 'heal-test',
          title: 'Old Title',
          fileName: 'Old File.md',
        );
        when(
          () => mockIndexingService.getDocument('heal-test'),
        ).thenReturn(doc);

        final note = await repository.getNoteById('heal-test');

        expect(note, isNotNull);
        expect(note!.fileName, equals('Renamed File.md'));
        expect(note.content, contains('Content here'));
        verify(() => mockIndexingService.upsertNote(any())).called(1);
      },
    );
  });

  // -------------------------------------------------------------------------
  // searchNoteIds / getNotesMetaData
  // -------------------------------------------------------------------------

  group('searchNotes', () {
    test('returns matching notes from IndexingService', () async {
      final meta1 = _makeMetaData(id: '1', title: 'matching title');
      final meta2 = _makeMetaData(id: '2', title: 'other');

      when(
        () => mockIndexingService.search('match'),
      ).thenAnswer((_) async => [meta1, meta2]);

      final result = await repository.getNotesMetaData(['2', '1']);

      expect(result.map((n) => n.id), ['2', '1']);
      verify(() => mockQuery.close()).called(1);
    });

    test('skips ids with no stored note', () async {
      final note1 = _makeNote(id: '1', title: 'first');
      when(() => mockQuery.findAsync()).thenAnswer((_) async => [note1]);

      final result = await repository.getNotesMetaData(['gone', '1']);

      expect(result.map((n) => n.id), ['1']);
    });

    test('does not query the box for an empty id list', () async {
      final result = await repository.getNotesMetaData([]);

      expect(result, isEmpty);
      verifyNever(() => mockBox.query(any()));
    });
  });

  // -------------------------------------------------------------------------
  // togglePinNote
  // -------------------------------------------------------------------------

  group('togglePinNote', () {
    test('calls IndexingService.togglePin', () async {
      when(
        () => mockIndexingService.togglePin('1'),
      ).thenAnswer((_) async => true);

      final result = await repository.togglePinNote('1');

      expect(result, isTrue);
      verify(() => mockIndexingService.togglePin('1')).called(1);
    });
  });
}
