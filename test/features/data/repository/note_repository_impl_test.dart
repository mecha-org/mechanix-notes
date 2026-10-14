import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository_impl.dart';
import 'package:mechanix_notes/features/notes/data/services/indexing_service.dart';
import 'package:mechanix_notes/features/notes/data/services/note_file_storage.dart';
import 'package:mechanix_notes/objectbox.g.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

// ---------------------------------------------------------------------------
// Mocks & Fakes
// ---------------------------------------------------------------------------

class MockBox extends Mock implements Box<NoteModel> {}

class MockQueryBuilder extends Mock implements QueryBuilder<NoteModel> {}

class MockQuery extends Mock implements Query<NoteModel> {}

class MockIndexingService extends Mock implements IndexingService {}

class FakeQueryProperty extends Fake
    implements QueryProperty<NoteModel, Object?> {}

class FakeQueryPropertyDateTime extends Fake
    implements QueryProperty<NoteModel, DateTime> {}

class FakeQueryPropertyInt extends Fake
    implements QueryProperty<NoteModel, int> {}

class FakeQueryPropertyString extends Fake
    implements QueryProperty<NoteModel, String> {}

class FakeQueryPropertyBool extends Fake
    implements QueryProperty<NoteModel, bool> {}

class FakeCondition extends Fake implements Condition<NoteModel> {}

// ---------------------------------------------------------------------------
// Testable subclass – lets us inject a fake Box without touching Store/Platform globals
// ---------------------------------------------------------------------------

class TestableNoteRepositoryImpl extends NoteRepositoryImpl {
  final Box<NoteModel> fakeBox;
  bool ensureStoreCalled = false;

  TestableNoteRepositoryImpl(
    this.fakeBox,
    IndexingService indexingService, {
    super.fileStorage,
  }) : super(indexingService: indexingService);

  /// Override the getter so the implementation uses our fake box.
  @override
  Box<NoteModel> get box => fakeBox;

  /// Skip real ObjectBox store initialization in tests.
  @override
  Future<void> ensureStoreConnected() async {
    ensureStoreCalled = true;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

NoteModel _makeNote({
  required String id,
  required String title,
  String previewText = '',
  double height = 200,
  DateTime? createdAt,
  DateTime? updatedAt,
  bool isPinned = false,
}) {
  final now = DateTime.now();
  return NoteModel(
    id: id,
    title: title,
    content: 'content',
    plainText: 'plainText',
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
  late MockBox mockBox;
  late MockQueryBuilder mockQueryBuilder;
  late MockQuery mockQuery;
  late MockIndexingService mockIndexingService;
  late NoteFileStorage fileStorage;
  late Directory tempDir;
  late TestableNoteRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(
      NoteModel(
        id: '',
        title: '',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        plainText: '',
        previewText: '',
        height: 0.0,
      ),
    );
    registerFallbackValue(FakeQueryProperty());
    registerFallbackValue(FakeQueryPropertyDateTime());
    registerFallbackValue(FakeQueryPropertyInt());
    registerFallbackValue(FakeQueryPropertyString());
    registerFallbackValue(FakeQueryPropertyBool());
    registerFallbackValue(FakeCondition());
    registerFallbackValue(const <int>[]);
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('note_repo_impl_test_');
    fileStorage = NoteFileStorage(notesDirectory: tempDir);
    mockBox = MockBox();
    mockQueryBuilder = MockQueryBuilder();
    mockQuery = MockQuery();
    mockIndexingService = MockIndexingService();
    repository = TestableNoteRepositoryImpl(
      mockBox,
      mockIndexingService,
      fileStorage: fileStorage,
    );

    // Setup default indexing stubs
    when(() => mockIndexingService.initialize()).thenAnswer((_) async {});
    when(
      () => mockIndexingService.upsertNote(any(), any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => mockIndexingService.deleteNotesBatch(any()),
    ).thenAnswer((_) async {});
    when(() => mockIndexingService.search(any())).thenAnswer((_) async => []);

    // Setup default query builder stubbing
    when(() => mockBox.query(any())).thenReturn(mockQueryBuilder);
    when(() => mockBox.query(null)).thenReturn(mockQueryBuilder);
    when(() => mockBox.query()).thenReturn(mockQueryBuilder);

    when(
      () => mockQueryBuilder.order<DateTime>(any(), flags: any(named: 'flags')),
    ).thenReturn(mockQueryBuilder);
    when(
      () => mockQueryBuilder.order<int>(any(), flags: any(named: 'flags')),
    ).thenReturn(mockQueryBuilder);
    when(
      () => mockQueryBuilder.order<String>(any(), flags: any(named: 'flags')),
    ).thenReturn(mockQueryBuilder);
    when(
      () => mockQueryBuilder.order<bool>(any(), flags: any(named: 'flags')),
    ).thenReturn(mockQueryBuilder);
    when(
      () => mockQueryBuilder.order(any(), flags: any(named: 'flags')),
    ).thenReturn(mockQueryBuilder);

    when(() => mockQueryBuilder.build()).thenReturn(mockQuery);
    when(() => mockQuery.close()).thenAnswer((_) {});
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // -------------------------------------------------------------------------
  // getNotes
  // -------------------------------------------------------------------------

  group('getNotes', () {
    test('returns empty list when box is empty', () async {
      when(() => mockQuery.find()).thenReturn([]);

      final result = await repository.getNotes(0, 10);

      expect(result, isEmpty);
      expect(repository.ensureStoreCalled, isTrue);
    });

    test('returns NoteMetaData list when box has notes', () async {
      final now = DateTime.now();
      final note1 = _makeNote(
        id: '1',
        title: 'Note 1',
        previewText: 'Preview 1',
        height: 150,
        updatedAt: now.subtract(const Duration(hours: 1)),
      );
      final note2 = _makeNote(
        id: '2',
        title: 'Note 2',
        previewText: 'Preview 2',
        height: 200,
        updatedAt: now,
      );

      when(() => mockQuery.find()).thenReturn([note1, note2]);

      final result = await repository.getNotes(0, 10);

      expect(result, hasLength(2));
      expect(result.map((n) => n.id), containsAll(['1', '2']));
    });

    test('maps NoteModel fields to NoteMetaData correctly', () async {
      final createdAt = DateTime(2024, 1, 1);
      final updatedAt = DateTime(2024, 6, 1);

      final note = _makeNote(
        id: 'abc',
        title: 'My Note',
        previewText: 'Some preview',
        height: 300,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      when(() => mockQuery.find()).thenReturn([note]);

      final result = await repository.getNotes(0, 10);

      expect(result, hasLength(1));
      final meta = result.first;
      expect(meta.id, equals('abc'));
      expect(meta.title, equals('My Note'));
      expect(meta.previewText, equals('Some preview'));
      expect(meta.height, equals(300));
      expect(meta.createdAt, equals(createdAt));
      expect(meta.updatedAt, equals(updatedAt));
    });

    test(
      'orders query by isPinned and updatedAt in descending order',
      () async {
        when(() => mockQuery.find()).thenReturn([]);

        await repository.getNotes(0, 10);

        verify(
          () => mockQueryBuilder.order(
            NoteModel_.isPinned,
            flags: Order.descending,
          ),
        ).called(1);
        verify(
          () => mockQueryBuilder.order(
            NoteModel_.updatedAt,
            flags: Order.descending,
          ),
        ).called(1);
      },
    );

    test('returns empty list and does not throw on exception', () async {
      when(() => mockQuery.find()).thenThrow(Exception('ObjectBox error'));

      final result = await repository.getNotes(0, 10);

      expect(result, isEmpty);
    });

    test('calls ensureStoreConnected before accessing box', () async {
      when(() => mockQuery.find()).thenReturn([]);

      await repository.getNotes(0, 10);

      expect(repository.ensureStoreCalled, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // getNoteById & getNoteMetaData
  // -------------------------------------------------------------------------

  group('getNoteById & getNoteMetaData', () {
    test('returns metadata of single note by id correctly', () async {
      final note = _makeNote(id: 'solo', title: 'Solo Note');
      when(() => mockQuery.findFirst()).thenReturn(note);

      final result = await repository.getNoteMetaData('solo');

      expect(result, isNotNull);
      expect(result!.id, equals('solo'));
    });

    test('returns NoteModel by id correctly', () async {
      final note = _makeNote(id: 'solo', title: 'Solo Note');
      when(() => mockQuery.findFirst()).thenReturn(note);

      final result = await repository.getNoteById('solo');

      expect(result, isNotNull);
      expect(result!.id, equals('solo'));
    });
  });

  // -------------------------------------------------------------------------
  // deleteNotes & upsertNote
  // -------------------------------------------------------------------------

  group('deleteNotes & upsertNote', () {
    test('deleteNotes calls removeMany with correct obxIds', () async {
      final note1 = _makeNote(id: '1', title: 'Note 1')..obxId = 10;
      final note2 = _makeNote(id: '2', title: 'Note 2')..obxId = 20;

      when(() => mockQuery.find()).thenReturn([note1, note2]);
      when(() => mockBox.removeMany(any())).thenReturn(2);

      await repository.deleteNotes(['1', '2']);

      verify(() => mockBox.removeMany([10, 20])).called(1);
    });

    test('upsertNote puts note and updates obxId if existing', () async {
      final note = _makeNote(id: '1', title: 'New Title');
      final existing = _makeNote(id: '1', title: 'Old Title')..obxId = 42;

      when(() => mockQuery.findFirst()).thenReturn(existing);
      when(() => mockBox.put(any())).thenReturn(42);

      await repository.upsertNote(note);

      expect(note.obxId, 42);
      verify(() => mockBox.put(note)).called(1);
    });

    test(
      'upsertNote propagates DbFullException when writing to box fails',
      () async {
        final note = _makeNote(id: '1', title: 'New Title');
        when(() => mockQuery.findFirst()).thenReturn(null);
        when(
          () => mockBox.put(any()),
        ).thenThrow(DbFullException('Disk full', 1018));

        expect(
          () => repository.upsertNote(note),
          throwsA(isA<DbFullException>()),
        );
      },
    );

    test(
      'upsertNote writes full markdown to .md file and stores filename in Box',
      () async {
        final note = _makeNote(id: 'save-test', title: 'File Test');
        note.content = '# Custom Markdown\n\n- item 1\n- item 2';

        when(() => mockQuery.findFirst()).thenReturn(null);
        when(() => mockBox.put(any())).thenReturn(1);

        await repository.upsertNote(note);

        expect(note.fileName, 'File Test.md');
        expect(await fileStorage.noteFileExists('File Test.md'), isTrue);
        final savedMarkdown = await fileStorage.readNoteContent('File Test.md');
        expect(
          savedMarkdown,
          '# Custom Markdown\n\n- item 1\n- item 2\n\n<!-- mechanix:id=save-test -->\n',
        );
        expect(note.content, '# Custom Markdown\n\n- item 1\n- item 2');
      },
    );

    test(
      'getNoteById reads full markdown from .md file and strips embedded tag',
      () async {
        await fileStorage.writeNoteContent(
          title: 'Open Test',
          markdown: '# Loaded from file\n\n<!-- mechanix:id=open-test -->\n',
        );

        final noteInDb = _makeNote(id: 'open-test', title: 'Open Test');
        noteInDb.fileName = 'Open Test.md';

        when(() => mockQuery.findFirst()).thenReturn(noteInDb);

        final result = await repository.getNoteById('open-test');

        expect(result, isNotNull);
        expect(result!.content, '# Loaded from file');
      },
    );

    test(
      'getNoteById auto-heals filename and title when file was renamed externally on disk',
      () async {
        await fileStorage.writeNoteContent(
          title: 'Renamed_File_Externally',
          markdown:
              '# Client Discussion\nNotes from client\n\n<!-- mechanix:id=healed-1 -->\n',
        );

        final noteInDb = _makeNote(id: 'healed-1', title: 'Old Title');
        noteInDb.fileName = 'Old Title.md';

        when(() => mockQuery.findFirst()).thenReturn(noteInDb);
        when(() => mockBox.put(any())).thenReturn(1);

        final result = await repository.getNoteById('healed-1');

        expect(result, isNotNull);
        expect(result!.fileName, 'Renamed_File_Externally.md');
        expect(result.title, 'Client Discussion');
        expect(result.content, '# Client Discussion\nNotes from client');
        verify(() => mockBox.put(noteInDb)).called(1);
      },
    );

    test('deleteNotes deletes corresponding .md file using fileName', () async {
      final fileName = await fileStorage.writeNoteContent(
        title: 'To Be Deleted',
        markdown: 'bye',
      );
      expect(await fileStorage.noteFileExists(fileName), isTrue);

      final note = _makeNote(id: 'del-1', title: 'To Be Deleted');
      note.fileName = fileName;
      note.obxId = 99;

      when(() => mockQuery.find()).thenReturn([note]);
      when(() => mockBox.removeMany(any())).thenReturn(1);

      await repository.deleteNotes(['del-1']);

      expect(await fileStorage.noteFileExists(fileName), isFalse);
    });

    test(
      'getNoteById sets isFileMissing = true and empty content when file does not exist on disk',
      () async {
        final noteInDb = _makeNote(id: 'missing-note', title: 'Ghost Note');
        noteInDb.fileName = 'NonExistent.md';

        when(() => mockQuery.findFirst()).thenReturn(noteInDb);

        final result = await repository.getNoteById('missing-note');

        expect(result, isNotNull);
        expect(result!.isFileMissing, isTrue);
        expect(result.content, isEmpty);
      },
    );

    test('getNoteFileLastModified returns timestamp when file exists and null when missing', () async {
      final fileName = await fileStorage.writeNoteContent(
        title: 'Modified Note',
        markdown: 'Some content\n<!-- mechanix:id=mod-note -->\n',
      );

      final noteInDb = _makeNote(id: 'mod-note', title: 'Modified Note');
      noteInDb.fileName = fileName;

      when(() => mockQuery.findFirst()).thenReturn(noteInDb);

      final modified = await repository.getNoteFileLastModified('mod-note');
      expect(modified, isNotNull);
      expect(modified!.isBefore(DateTime.now().add(const Duration(seconds: 1))), isTrue);

      // Missing note
      when(() => mockQuery.findFirst()).thenReturn(null);
      final nullModified = await repository.getNoteFileLastModified('nonexistent');
      expect(nullModified, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // searchNotes
  // -------------------------------------------------------------------------

  group('searchNotes', () {
    test('queries box with title and preview text contains', () async {
      final note1 = _makeNote(id: '1', title: 'matching title');
      final note2 = _makeNote(
        id: '2',
        title: 'other',
        previewText: 'matching preview',
      );

      when(
        () => mockIndexingService.search('match'),
      ).thenAnswer((_) async => ['1', '2']);
      when(() => mockQuery.find()).thenReturn([note1, note2]);

      final result = await repository.searchNotes('match');

      expect(result, hasLength(2));
      expect(result.map((n) => n.id), containsAll(['1', '2']));
    });
  });

  // -------------------------------------------------------------------------
  // togglePinNote
  // -------------------------------------------------------------------------

  group('togglePinNote', () {
    test('toggles note from false to true', () async {
      final note = _makeNote(id: '1', title: 'Note 1', isPinned: false);
      when(() => mockQuery.findFirst()).thenReturn(note);
      when(() => mockBox.put(any())).thenReturn(1);

      final result = await repository.togglePinNote('1');

      expect(result, isTrue);
      expect(note.isPinned, isTrue);
      verify(() => mockBox.put(note)).called(1);
    });

    test('toggles note from true to false', () async {
      final note = _makeNote(id: '2', title: 'Note 2', isPinned: true);
      when(() => mockQuery.findFirst()).thenReturn(note);
      when(() => mockBox.put(any())).thenReturn(1);

      final result = await repository.togglePinNote('2');

      expect(result, isFalse);
      expect(note.isPinned, isFalse);
      verify(() => mockBox.put(note)).called(1);
    });

    test('returns false when note is not found', () async {
      when(() => mockQuery.findFirst()).thenReturn(null);

      final result = await repository.togglePinNote('unknown');

      expect(result, isFalse);
      verifyNever(() => mockBox.put(any()));
    });
  });

  // -------------------------------------------------------------------------
  // reconcileWithDisk
  // -------------------------------------------------------------------------

  group('reconcileWithDisk', () {
    test('adopts new untagged file, appends tag, and indexes note', () async {
      when(() => mockBox.getAll()).thenReturn([]);
      when(() => mockBox.put(any())).thenReturn(1);

      // Create an untagged external file
      final file = File(p.join(tempDir.path, 'Meeting Notes.md'));
      await file.writeAsString('# Meeting Notes\nDiscussed architecture and next steps');

      await repository.reconcileWithDisk();

      // Verify that tag was appended to the file on disk
      final diskContent = await file.readAsString();
      expect(diskContent, contains('<!-- mechanix:id='));
      expect(diskContent, contains('# Meeting Notes'));

      // Verify note was inserted into Box
      final captured = verify(() => mockBox.put(captureAny())).captured;
      expect(captured, isNotEmpty);
      final adoptedNote = captured.first as NoteModel;
      expect(adoptedNote.title, 'Meeting Notes');
      expect(adoptedNote.previewText, contains('Discussed architecture and next steps'));
      expect(adoptedNote.fileName, 'Meeting Notes.md');

      // Verify note was indexed in Tantivy
      verify(
        () => mockIndexingService.upsertNote(
          adoptedNote.id,
          'Meeting Notes',
          any(),
        ),
      ).called(1);
    });

    test('adopts new tagged file when note is not in box', () async {
      when(() => mockBox.getAll()).thenReturn([]);
      when(() => mockBox.put(any())).thenReturn(1);
      when(() => mockQuery.findFirst()).thenReturn(null);

      final file = File(p.join(tempDir.path, 'External Tagged.md'));
      await file.writeAsString(
        '# External Tagged\nBody content\n<!-- mechanix:id=ext-tagged-123 -->',
      );

      await repository.reconcileWithDisk();

      final captured = verify(() => mockBox.put(captureAny())).captured;
      expect(captured, isNotEmpty);
      final adoptedNote = captured.first as NoteModel;
      expect(adoptedNote.id, 'ext-tagged-123');
      expect(adoptedNote.title, 'External Tagged');
      expect(adoptedNote.previewText, contains('Body content'));

      verify(
        () => mockIndexingService.upsertNote(
          'ext-tagged-123',
          'External Tagged',
          any(),
        ),
      ).called(1);
    });

    test('updates existing note if disk content has changed', () async {
      final existingNote = _makeNote(
        id: 'existing-id',
        title: 'Old Title',
      )..fileName = 'My Note.md'
       ..content = '# Old Title\nOld content';

      when(() => mockBox.getAll()).thenReturn([existingNote]);
      when(() => mockQuery.findFirst()).thenReturn(existingNote);
      when(() => mockBox.put(any())).thenReturn(1);

      // File has been edited externally
      final file = File(p.join(tempDir.path, 'My Note.md'));
      await file.writeAsString(
        '# New Title\nUpdated content from outside\n<!-- mechanix:id=existing-id -->',
      );

      await repository.reconcileWithDisk();

      expect(existingNote.title, 'New Title');
      expect(existingNote.content, contains('# New Title\nUpdated content from outside'));
      verify(() => mockBox.put(existingNote)).called(1);
      verify(
        () => mockIndexingService.upsertNote(
          'existing-id',
          'New Title',
          any(),
        ),
      ).called(1);
    });

    test('deletes note from box and index when file is removed from disk', () async {
      final staleNote = _makeNote(
        id: 'stale-id',
        title: 'Deleted Note',
      )..fileName = 'deleted_file.md'
       ..obxId = 42;

      when(() => mockBox.getAll()).thenReturn([staleNote]);
      when(() => mockBox.remove(42)).thenReturn(true);

      // No file created on disk

      await repository.reconcileWithDisk();

      verify(() => mockBox.remove(42)).called(1);
      verify(
        () => mockIndexingService.deleteNotesBatch(['stale-id']),
      ).called(1);
    });
  });
}
