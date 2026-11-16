import 'dart:async';
import 'dart:io';

import 'package:flutter_tantivy/flutter_tantivy.dart' as tantivy;
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/exceptions/storage_exception.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
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

/// The metadata-only view of [d], as returned by getAllMetadata.
tantivy.NoteMeta _metaOf(tantivy.Document d) => tantivy.NoteMeta(
  id: d.id,
  title: d.title,
  previewText: d.previewText,
  fileName: d.fileName,
  isPinned: d.isPinned,
  createdAt: d.createdAt,
  updatedAt: d.updatedAt,
);

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
    when(() => mockIndexingService.upsertNotesBatch(any())).thenAnswer((
      invocation,
    ) async {
      final notes = invocation.positionalArguments[0] as List<NoteModel>;
      for (final note in notes) {
        await mockIndexingService.upsertNote(note);
      }
    });
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
    when(
      () => mockIndexingService.getAllMetadata(),
    ).thenAnswer((_) async => []);
  });

  tearDown(() async {
    await repository.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // -------------------------------------------------------------------------
  // watchNotes
  // -------------------------------------------------------------------------

  group('watchNotes', () {
    test('emits initial notes and re-emits when a note is updated', () async {
      final note1 = _makeMetaData(id: '1', title: 'Note 1');
      final note2 = _makeMetaData(id: '2', title: 'Note 2');

      when(
        () => mockIndexingService.getNotes(
          skip: any(named: 'skip'),
          take: any(named: 'take'),
        ),
      ).thenAnswer((_) async => [note1]);

      final emissions = <List<NoteMetaData>>[];
      final sub = repository.watchNotes().listen(emissions.add);

      try {
        await pumpEventQueue();
        expect(emissions.length, 1);
        expect(emissions.first.first.id, '1');

        when(
          () => mockIndexingService.getNotes(
            skip: any(named: 'skip'),
            take: any(named: 'take'),
          ),
        ).thenAnswer((_) async => [note1, note2]);

        await repository.upsertNote(_makeNote(id: '2', title: 'Note 2'));
        await pumpEventQueue();

        expect(emissions.length, 2);
        expect(emissions.last.length, 2);
      } finally {
        await sub.cancel();
      }
    });

    test(
      'reads the index once, then applies saves, renames and deletes '
      'without re-reading it',
      () async {
        when(
          () => mockIndexingService.getNotes(
            skip: any(named: 'skip'),
            take: any(named: 'take'),
          ),
        ).thenAnswer(
          (_) async => [
            _makeMetaData(
              id: 'Old.md',
              title: 'Old',
              updatedAt: DateTime(2026, 1, 1),
            ),
          ],
        );

        final emissions = <List<NoteMetaData>>[];
        final sub = repository.watchNotes().listen(emissions.add);
        List<String> ids() => emissions.last.map((n) => n.id).toList();

        try {
          await pumpEventQueue();
          expect(ids(), ['Old.md']);

          // New note: appears at the top (most recently updated).
          final created = await repository.upsertNote(
            _makeNote(id: 'uuid-1', title: 'Fresh')..content = '# Fresh',
          );
          await pumpEventQueue();
          expect(created, 'Fresh.md');
          expect(ids(), ['Fresh.md', 'Old.md']);

          // Title change renames the file: one emission, entry replaced.
          final before = emissions.length;
          await repository.upsertNote(
            _makeNote(id: 'Fresh.md', title: 'Renamed', fileName: 'Fresh.md')
              ..content = '# Renamed',
          );
          await pumpEventQueue();
          expect(emissions.length, before + 1);
          expect(ids(), ['Renamed.md', 'Old.md']);

          when(
            () => mockIndexingService.getDocument('Renamed.md'),
          ).thenReturn(null);
          await repository.deleteNotes(['Renamed.md']);
          await pumpEventQueue();
          expect(ids(), ['Old.md']);

          verify(
            () => mockIndexingService.getNotes(
              skip: any(named: 'skip'),
              take: any(named: 'take'),
            ),
          ).called(1);
        } finally {
          await sub.cancel();
        }
      },
    );

    test('keeps pinned notes first, matching the index order', () async {
      when(
        () => mockIndexingService.getNotes(
          skip: any(named: 'skip'),
          take: any(named: 'take'),
        ),
      ).thenAnswer(
        (_) async => [
          _makeMetaData(
            id: 'Pinned.md',
            title: 'Pinned',
            isPinned: true,
            updatedAt: DateTime(2020),
          ),
        ],
      );

      final emissions = <List<NoteMetaData>>[];
      final sub = repository.watchNotes().listen(emissions.add);
      try {
        await pumpEventQueue();
        await repository.upsertNote(
          _makeNote(id: 'n', title: 'Newer')..content = '# Newer',
        );
        await pumpEventQueue();
        expect(emissions.last.map((n) => n.id), ['Pinned.md', 'Newer.md']);
      } finally {
        await sub.cancel();
      }
    });

    test('re-reads the index after a disk sync', () async {
      when(
        () => mockIndexingService.getNotes(
          skip: any(named: 'skip'),
          take: any(named: 'take'),
        ),
      ).thenAnswer((_) async => []);

      final emissions = <List<NoteMetaData>>[];
      final sub = repository.watchNotes().listen(emissions.add);
      try {
        await pumpEventQueue();
        File('${tempDir.path}/External.md').writeAsStringSync('# External');
        when(
          () => mockIndexingService.getNotes(
            skip: any(named: 'skip'),
            take: any(named: 'take'),
          ),
        ).thenAnswer(
          (_) async => [_makeMetaData(id: 'External.md', title: 'External')],
        );

        expect(await repository.syncNotesFromDisk(), 1);
        await pumpEventQueue();

        expect(emissions.last.map((n) => n.id), ['External.md']);
        verify(
          () => mockIndexingService.getNotes(
            skip: any(named: 'skip'),
            take: any(named: 'take'),
          ),
        ).called(2);
      } finally {
        await sub.cancel();
      }
    });

    test('does not subscribe if cancelled while initializing', () async {
      final init = Completer<void>();
      when(() => mockIndexingService.initialize()).thenAnswer((_) => init.future);

      final sub = repository.watchNotes().listen((_) {});
      await pumpEventQueue();
      await sub.cancel();
      init.complete();
      await pumpEventQueue();

      verifyNever(
        () => mockIndexingService.getNotes(
          skip: any(named: 'skip'),
          take: any(named: 'take'),
        ),
      );
    });

    test('re-throws when indexingService.initialize fails', () async {
      when(
        () => mockIndexingService.initialize(),
      ).thenAnswer((_) => Future.error(StateError('init failed')));

      expect(() => repository.watchNotes().first, throwsA(isA<StateError>()));
    });
  });

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

      await fileStorage.createNoteFile(
        title: 'Note 1',
        markdown: 'content 1',
      );
      await fileStorage.createNoteFile(
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
        expect(savedContent, equals('My awesome note content\n'));
        expect(savedContent, isNot(contains('mechanix:id')));

        verify(() => mockIndexingService.upsertNote(any())).called(1);
      },
    );

    test(
      'upsertNote on a title change renames the file, returns the new id '
      'and emits NoteRenamed',
      () async {
        final created = await repository.upsertNote(
          _makeNote(id: 'uuid-1', title: 'Foo')..content = '# Foo',
        );
        expect(created, 'Foo.md');

        final renamed = expectLater(
          repository.noteRenames,
          emits(
            isA<NoteRenamed>()
                .having((r) => r.oldId, 'oldId', 'Foo.md')
                .having((r) => r.newId, 'newId', 'Bar.md'),
          ),
        );
        final updated = await repository.upsertNote(
          _makeNote(id: 'Foo.md', title: 'Bar', fileName: 'Foo.md')
            ..content = '# Bar',
        );
        await renamed;

        expect(updated, 'Bar.md');
        final names = tempDir.listSync().map((e) => e.uri.pathSegments.last);
        expect(names, ['Bar.md']);
      },
    );

    test(
      'upsertNote throws NoteFileMissingException instead of writing a copy',
      () async {
        await fileStorage.createNoteFile(title: 'Hello', markdown: 'other');

        await expectLater(
          repository.upsertNote(
            _makeNote(id: 'gone.md', title: 'Hello', fileName: 'gone.md'),
          ),
          throwsA(isA<NoteFileMissingException>()),
        );
        final names = tempDir.listSync().map((e) => e.uri.pathSegments.last);
        expect(names, ['Hello.md']);
        verifyNever(() => mockIndexingService.upsertNote(any()));
      },
    );

    test(
      'getNoteById reads full markdown from .md file using fileName',
      () async {
        await fileStorage.createNoteFile(
          title: 'Open Test',
          markdown: 'Body text here',
        );

        final doc = _makeDoc(
          id: 'Open Test.md',
          title: 'Open Test',
          fileName: 'Open Test.md',
        );
        when(
          () => mockIndexingService.getDocument('Open Test.md'),
        ).thenReturn(doc);

        final note = await repository.getNoteById('Open Test.md');

        expect(note, isNotNull);
        expect(note!.content, equals('Body text here'));
      },
    );
  });

  // -------------------------------------------------------------------------
  // searchNoteIds / getNotesMetaData
  // -------------------------------------------------------------------------

  group('searchNoteIds / getNotesMetaData', () {
    test('searchNoteIds returns ids from IndexingService in order', () async {
      final meta1 = _makeMetaData(id: '1', title: 'matching title');
      final meta2 = _makeMetaData(id: '2', title: 'other');
      when(
        () => mockIndexingService.search('match'),
      ).thenAnswer((_) async => [meta1, meta2]);

      final result = await repository.searchNoteIds('match');

      expect(result, ['1', '2']);
    });

    test('getNotesMetaData keeps the caller order', () async {
      when(
        () => mockIndexingService.getNoteMetaData('1'),
      ).thenReturn(_makeMetaData(id: '1', title: 'first'));
      when(
        () => mockIndexingService.getNoteMetaData('2'),
      ).thenReturn(_makeMetaData(id: '2', title: 'second'));

      final result = await repository.getNotesMetaData(['2', '1']);

      expect(result.map((n) => n.id), ['2', '1']);
    });

    test('skips ids with no stored note', () async {
      when(
        () => mockIndexingService.getNoteMetaData('1'),
      ).thenReturn(_makeMetaData(id: '1', title: 'first'));
      when(() => mockIndexingService.getNoteMetaData('gone')).thenReturn(null);

      final result = await repository.getNotesMetaData(['gone', '1']);

      expect(result.map((n) => n.id), ['1']);
    });

    test('does not touch the index for an empty id list', () async {
      final result = await repository.getNotesMetaData([]);

      expect(result, isEmpty);
      verifyNever(() => mockIndexingService.getNoteMetaData(any()));
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

  // -------------------------------------------------------------------------
  // syncNotesFromDisk
  // -------------------------------------------------------------------------

  group('syncNotesFromDisk', () {
    test(
      'indexes newly dropped .md files without writing an ID tag to them',
      () async {
        final file = File('${tempDir.path}/external_note.md');
        const original = '# External Title\nBody of external note';
        await file.writeAsString(original);

        final updatedCount = await repository.syncNotesFromDisk();

        expect(updatedCount, equals(1));
        verify(
          () => mockIndexingService.upsertNote(
            any(
              that: isA<NoteModel>()
                  .having((n) => n.title, 'title', 'External Title')
                  .having((n) => n.fileName, 'fileName', 'external_note.md'),
            ),
          ),
        ).called(1);

        // File on disk is left untouched
        expect(await file.readAsString(), equals(original));
      },
    );

    test(
      'purges ghost notes from Tantivy whose files were deleted on disk',
      () async {
        final ghostDoc = _makeDoc(
          id: 'ghost-1',
          title: 'Ghost Note',
          fileName: 'ghost.md',
        );
        when(
          () => mockIndexingService.getAllMetadata(),
        ).thenAnswer((_) async => [_metaOf(ghostDoc)]);

        final updatedCount = await repository.syncNotesFromDisk();

        expect(updatedCount, equals(1));
        verify(
          () => mockIndexingService.deleteNotesBatch(['ghost-1']),
        ).called(1);
      },
    );

    test(
      're-indexes files whose modified time is newer than indexed updatedAt',
      () async {
        final file = File('${tempDir.path}/modified_note.md');
        await file.writeAsString('# Updated Title\nUpdated Body\n');

        final oldUpdatedAt = DateTime.now().subtract(
          const Duration(minutes: 10),
        );
        final doc = _makeDoc(
          id: 'modified_note.md',
          title: 'Old Title',
          updatedAt: oldUpdatedAt,
          fileName: 'modified_note.md',
        );
        when(
          () => mockIndexingService.getAllMetadata(),
        ).thenAnswer((_) async => [_metaOf(doc)]);

        final updatedCount = await repository.syncNotesFromDisk();

        expect(updatedCount, equals(1));
        verify(
          () => mockIndexingService.upsertNote(
            any(
              that: isA<NoteModel>()
                  .having((n) => n.id, 'id', 'modified_note.md')
                  .having((n) => n.title, 'title', 'Updated Title'),
            ),
          ),
        ).called(1);
        verifyNever(() => mockIndexingService.deleteNotesBatch(any()));
      },
    );

    test(
      're-indexes legacy UUID docs with filename ID and purges old index entry',
      () async {
        final file = File('${tempDir.path}/renamed_note.md');
        await file.writeAsString('# Note 1\nBody\n');
        final fileModified = (await file.stat()).modified;

        final doc = _makeDoc(
          id: 'legacy-uuid-1',
          title: 'Note 1',
          updatedAt: fileModified,
          fileName: 'renamed_note.md',
        );
        when(
          () => mockIndexingService.getAllMetadata(),
        ).thenAnswer((_) async => [_metaOf(doc)]);

        final updatedCount = await repository.syncNotesFromDisk();

        expect(updatedCount, equals(2));
        verify(
          () => mockIndexingService.upsertNote(
            any(
              that: isA<NoteModel>()
                  .having((n) => n.id, 'id', 'renamed_note.md')
                  .having((n) => n.fileName, 'fileName', 'renamed_note.md'),
            ),
          ),
        ).called(1);
        verify(
          () => mockIndexingService.deleteNotesBatch(['legacy-uuid-1']),
        ).called(1);
      },
    );

    test(
      'purges ghost note from Tantivy and returns null when file is missing from disk (Alternative 2)',
      () async {
        final doc = _makeDoc(
          id: 'ghost-note',
          title: 'Ghost Title',
          fileName: 'missing_on_disk.md',
        );
        when(
          () => mockIndexingService.getDocument('ghost-note'),
        ).thenReturn(doc);

        final result = await repository.getNoteById('ghost-note');

        expect(result, isNull);
        verify(
          () => mockIndexingService.deleteNotesBatch(['ghost-note']),
        ).called(1);
      },
    );

    test(
      'batches multiple modified notes into a single upsertNotesBatch call',
      () async {
        final file1 = File('${tempDir.path}/note1.md');
        await file1.writeAsString('# Note 1\nBody 1\n');
        final file2 = File('${tempDir.path}/note2.md');
        await file2.writeAsString('# Note 2\nBody 2\n');

        final updatedCount = await repository.syncNotesFromDisk();

        expect(updatedCount, equals(2));
        verify(
          () => mockIndexingService.upsertNotesBatch(
            any(
              that: isA<List<NoteModel>>().having(
                (list) => list.map((n) => n.id).toList(),
                'ids',
                containsAll(['note1.md', 'note2.md']),
              ),
            ),
          ),
        ).called(1);
      },
    );

    test(
      'matches an unmodified file to its note by filename and skips re-indexing',
      () async {
        final file = File('${tempDir.path}/unmodified.md');
        await file.writeAsString('# Unmodified\nBody\n');

        final stat = await file.stat();
        final doc = _makeDoc(
          id: 'unmodified.md',
          title: 'Unmodified',
          updatedAt: stat.modified,
          fileName: 'unmodified.md',
        );
        when(
          () => mockIndexingService.getAllMetadata(),
        ).thenAnswer((_) async => [_metaOf(doc)]);

        final updatedCount = await repository.syncNotesFromDisk();

        expect(updatedCount, equals(0));
        verifyNever(() => mockIndexingService.upsertNotesBatch(any()));
        verifyNever(() => mockIndexingService.upsertNote(any()));
        verifyNever(() => mockIndexingService.deleteNotesBatch(any()));
      },
    );
  });
}
