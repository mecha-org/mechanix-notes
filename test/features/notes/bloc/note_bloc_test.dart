import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mechanix_notes/core/exceptions/storage_exception.dart';
import 'package:mechanix_notes/core/utils/constants.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_event.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_state.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/models/time_group.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';

// ---------------------------------------------------------------------------
// Fake repository: in-memory notes, sorted and watched like the ObjectBox query
// ---------------------------------------------------------------------------

class FakeNoteRepository implements NoteRepository {
  final Map<String, NoteMetaData> _notes = {};
  final _changes = StreamController<void>.broadcast();
  Object? watchError;
  Object? deleteError;
  int watchCount = 0;
  final List<List<String>> deletedBatches = [];

  FakeNoteRepository([Iterable<NoteMetaData> notes = const []]) {
    for (final n in notes) {
      _notes[n.id] = n;
    }
  }

  List<NoteMetaData> get sorted => _notes.values.toList()
    ..sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

  List<String> get sortedIds => sorted.map((n) => n.id).toList();

  void save(NoteMetaData note) {
    _notes[note.id] = note;
    _changes.add(null);
  }

  void remove(String id) {
    _notes.remove(id);
    _changes.add(null);
  }

  @override
  Stream<List<NoteMetaData>> watchNotes() async* {
    watchCount++;
    if (watchError != null) throw watchError!;
    yield sorted;
    yield* _changes.stream.map((_) => sorted);
  }

  @override
  Future<void> deleteNotes(List<String> ids) async {
    if (deleteError != null) throw deleteError!;
    deletedBatches.add(ids);
    ids.forEach(_notes.remove);
    _changes.add(null);
  }

  @override
  Future<bool> togglePinNote(String id) async {
    final n = _notes[id]!;
    save(note(n.id, n.updatedAt, pinned: !n.isPinned));
    return !n.isPinned;
  }

  @override
  Future<NoteModel?> getNoteById(String id) async => null;

  @override
  Future<void> upsertNote(NoteModel note) async {}

  @override
  Future<List<String>> searchNoteIds(String query) async => [];

  @override
  Future<List<NoteMetaData>> getNotesMetaData(List<String> ids) async => [];

  @override
  Future<void> close() async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void main() {
  late MockNoteRepository mockRepo;

  setUp(() {
    mockRepo = MockNoteRepository();
    when(
      () => mockRepo.getNotesFromTantivy(limit: any(named: 'limit')),
    ).thenAnswer((_) async => []);
    initializeDateFormatting('en');
  });

  // ── Constructor ──────────────────────────────────────────────────────────

  group('NotesBloc – constructor', () {
    test('initial state is default NotesState', () {
      when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => []);
      final bloc = NotesBloc(noteRepository: mockRepo);
      expect(bloc.state, const NotesState());
      bloc.close();
    });

    test('dispatches LoadNotes on creation', () async {
      when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => []);
      final bloc = NotesBloc(noteRepository: mockRepo);
      await bloc.stream.first;
      verify(() => mockRepo.getNotes(any(), any())).called(1);
      await bloc.close();
    });
  });

  // ── LoadNotes – success ───────────────────────────────────────────────────

  group('LoadNotes – success', () {
    blocTest<NotesBloc, NotesState>(
      'emits [loading, loaded] with empty list when repository returns nothing',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => []);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      expect: () => [
        isA<NotesState>().having((s) => s.isLoading, 'isLoading', true),
        isA<NotesState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.notes, 'notes', isEmpty)
            .having((s) => s.groupedNotes, 'groupedNotes', isEmpty)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.error, 'error', isNull),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'emits loaded state with correct notes when count ≤ pageSize',
      build: () {
        final notes = buildNoteList(5);
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      expect: () => [
        isA<NotesState>().having((s) => s.isLoading, 'isLoading', true),
        isA<NotesState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.notes.length, 'notes.length', 5)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.currentPage, 'currentPage', 0),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'sets hasMore=true when total notes exceed pageSize',
      build: () {
        final notes = buildNoteList(Constants.pageSize + 5);
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      expect: () => [
        isA<NotesState>().having((s) => s.isLoading, 'isLoading', true),
        isA<NotesState>()
            .having((s) => s.hasMore, 'hasMore', true)
            .having((s) => s.notes.length, 'notes.length', Constants.pageSize),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'resets currentPage to 0 on fresh load',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => buildNoteList(3));
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      expect: () => [
        isA<NotesState>(),
        isA<NotesState>().having((s) => s.currentPage, 'currentPage', 0),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'clears previous error on successful reload',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => []);
        return NotesBloc(noteRepository: mockRepo);
      },
      seed: () => const NotesState(
        error: ErrorCategory.failedToLoadNotes,
        isLoading: false,
        hasMore: false,
      ),
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      expect: () => [
        isA<NotesState>()
            .having((s) => s.isLoading, 'isLoading', true)
            .having((s) => s.error, 'error', isNull),
        isA<NotesState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.error, 'error', isNull),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'groupedNotes contains exactly pageSize notes when total > pageSize',
      build: () {
        final notes = buildNoteList(Constants.pageSize + 10);
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        final visibleNotes = extractNotes(bloc.state.groupedNotes);
        expect(visibleNotes.length, Constants.pageSize);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'stores only first page of notes in state.notes when total exceeds pageSize',
      build: () {
        final notes = buildNoteList(Constants.pageSize + 10);
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        expect(bloc.state.notes.length, Constants.pageSize);
      },
    );
  });

  // ── LoadNotes – failure ───────────────────────────────────────────────────

  group('LoadNotes – failure', () {
    blocTest<NotesBloc, NotesState>(
      'emits error state when repository throws',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenThrow(Exception('db error'));
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      expect: () => [
        isA<NotesState>().having((s) => s.isLoading, 'isLoading', true),
        isA<NotesState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.error, 'error', isNotNull)
            .having((s) => s.notes, 'notes', isEmpty),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'emits failedToLoadNotes error category on generic exception',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenThrow(Exception('any'));
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      expect: () => [
        isA<NotesState>(),
        isA<NotesState>().having(
          (s) => s.error,
          'error',
          ErrorCategory.failedToLoadNotes,
        ),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'emits appAlreadyRunning error when ObjectBoxException is thrown',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenThrow(ObjectBoxException());
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      expect: () => [
        isA<NotesState>(),
        isA<NotesState>().having(
          (s) => s.error,
          'error',
          ErrorCategory.appAlreadyRunning,
        ),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'notes remain empty after failed load',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenThrow(Exception('any'));
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        expect(bloc.state.notes, isEmpty);
        expect(bloc.state.groupedNotes, isEmpty);
      },
    );
  });

  // ── Grouping / time labels ────────────────────────────────────────────────

  group('_buildFlattenedNotes – time groups', () {
    blocTest<NotesBloc, NotesState>(
      'assigns TimeCategory.recent for a note updated less than 2 hours ago',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [recentNote('r1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        expect(
          hasCategory(bloc.state.groupedNotes, TimeCategory.recent),
          isTrue,
        );
      },
    );

    blocTest<NotesBloc, NotesState>(
      'assigns TimeCategory.today for a note updated earlier today (≥2 h ago)',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [todayNote('t1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        expect(
          hasCategory(bloc.state.groupedNotes, TimeCategory.today),
          isTrue,
        );
      },
    );

    blocTest<NotesBloc, NotesState>(
      'assigns TimeCategory.last7Days for a note updated yesterday',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [yesterdayNote('y1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        expect(
          hasCategory(bloc.state.groupedNotes, TimeCategory.last7Days),
          isTrue,
        );
      },
    );

    blocTest<NotesBloc, NotesState>(
      'assigns TimeCategory.last7Days for a note from this week',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [thisWeekNote('w1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        expect(
          hasCategory(bloc.state.groupedNotes, TimeCategory.last7Days),
          isTrue,
        );
      },
    );

    blocTest<NotesBloc, NotesState>(
      'assigns TimeCategory.last7Days for a note 6 days ago',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [lastWeekNote('lw1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        expect(
          hasCategory(bloc.state.groupedNotes, TimeCategory.last7Days),
          isTrue,
        );
      },
    );

    blocTest<NotesBloc, NotesState>(
      'assigns TimeCategory.lastMonth or last7Days for a note from this month start',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [thisMonthNote('tm1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        final categories = extractCategories(bloc.state.groupedNotes);
        expect(
          categories.any(
            (c) => c == TimeCategory.lastMonth || c == TimeCategory.last7Days,
          ),
          isTrue,
        );
      },
    );

    blocTest<NotesBloc, NotesState>(
      'assigns TimeCategory.lastMonth for a note from last month',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [lastMonthNote('lm1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        expect(
          hasCategory(bloc.state.groupedNotes, TimeCategory.lastMonth),
          isTrue,
        );
      },
    );

    blocTest<NotesBloc, NotesState>(
      'assigns TimeCategory.custom for a note older than 30 days',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [olderNote('o1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        expect(
          hasCategory(bloc.state.groupedNotes, TimeCategory.custom),
          isTrue,
        );
      },
    );

    blocTest<NotesBloc, NotesState>(
      'custom TimeGroup has a non-null customLabel formatted as "MMMM yyyy"',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [olderNote('o1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        final customGroups = extractTimeGroups(
          bloc.state.groupedNotes,
        ).where((g) => g.category == TimeCategory.custom).toList();
        expect(customGroups, isNotEmpty);
        expect(customGroups.first.customLabel, isNotNull);
        expect(
          customGroups.first.customLabel,
          matches(RegExp(r'^[A-Za-z]+ \d{4}$')),
        );
      },
    );

    blocTest<NotesBloc, NotesState>(
      'does NOT repeat the same TimeGroup for consecutive notes in the same group',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenAnswer(
          (_) async => [recentNote('r1'), recentNote('r2'), recentNote('r3')],
        );
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        final groups = extractTimeGroups(bloc.state.groupedNotes);
        final recentCount = groups
            .where((g) => g.category == TimeCategory.recent)
            .length;
        expect(recentCount, 1);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'inserts a new TimeGroup when the time category changes across notes',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [recentNote('r1'), lastMonthNote('lm1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        final categories = extractCategories(bloc.state.groupedNotes);
        expect(categories, contains(TimeCategory.recent));
        expect(categories, contains(TimeCategory.lastMonth));
        expect(categories.length, 2);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'flattened list alternates TimeGroups and NoteMetaData in correct order',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [recentNote('r1'), lastMonthNote('lm1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        final grouped = bloc.state.groupedNotes;
        // Expected: [TimeGroup, NoteMetaData, TimeGroup, NoteMetaData]
        expect(grouped[0], isA<TimeGroup>());
        expect(grouped[1], isA<NoteMetaData>());
        expect(grouped[2], isA<TimeGroup>());
        expect(grouped[3], isA<NoteMetaData>());
      },
    );

    blocTest<NotesBloc, NotesState>(
      'single note produces exactly one TimeGroup and one NoteMetaData',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [recentNote('r1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        expect(bloc.state.groupedNotes.length, 2);
        expect(bloc.state.groupedNotes[0], isA<TimeGroup>());
        expect(bloc.state.groupedNotes[1], isA<NoteMetaData>());
      },
    );
  });

  // ── LoadMoreNotes – success ───────────────────────────────────────────────

  group('LoadMoreNotes – success', () {
    blocTest<NotesBloc, NotesState>(
      'sets hasMore=true when total notes exceed pageSize',
      build: () {
        final notes = buildNoteList(Constants.pageSize + 5);
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      expect: () => [
        isA<NotesState>().having((s) => s.isLoading, 'isLoading', true),
        isA<NotesState>()
            .having((s) => s.hasMore, 'hasMore', true)
            .having((s) => s.notes.length, 'notes.length', Constants.pageSize),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'increments currentPage after loading more',
      build: () {
        final notes = buildNoteList(Constants.pageSize * 2);
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadMoreNotes()),
      expect: () => [
        isA<NotesState>(),
        isA<NotesState>().having((s) => s.currentPage, 'currentPage', 1),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'sets hasMore=true when another full page is available',
      build: () {
        final notes = buildNoteList(Constants.pageSize * 2);
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadMoreNotes()),
      expect: () => [
        isA<NotesState>(),
        isA<NotesState>().having((s) => s.hasMore, 'hasMore', true),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'does not duplicate the section TimeGroup when new batch is in the same group',
      build: () {
        final notes = buildNoteList(Constants.pageSize + 5);
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadMoreNotes()),
      verify: (bloc) {
        final groups = extractTimeGroups(bloc.state.groupedNotes);
        final recentCount = groups
            .where((g) => g.category == TimeCategory.recent)
            .length;
        expect(recentCount, 1);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'appends new notes to groupedNotes after load more',
      build: () {
        final notes = buildNoteList(Constants.pageSize + 5);
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadMoreNotes()),
      verify: (bloc) {
        final visibleNotes = extractNotes(bloc.state.groupedNotes);
        expect(visibleNotes.length, Constants.pageSize + 5);
      },
    );
  });

  // The list must match the repository after every kind of change and at every
  // size. These used to fail with offset pagination (missing notes after
  // create/edit/delete, stale pin state, duplicates during a page load).
  for (final count in [10, 20, 1000]) {
    group('live updates with $count notes', () {
      setUp(() async {
        repo = FakeNoteRepository(notesSpacedBy3h(count));
        bloc = buildBloc(repo);
        await pumpEventQueue();
      });

      test('shows every note on load', () {
        expect(bloc.state.notes, hasLength(count));
        expectInSync(bloc, repo);
      });

      test('a new note appears at the top and none go missing', () async {
        repo.save(note('new', base.add(const Duration(minutes: 1))));
        await pumpEventQueue();

        expect(visibleIds(bloc).first, 'new');
        expect(bloc.state.notes, hasLength(count + 1));
        expectInSync(bloc, repo);
      });

      test('an edited older note moves to the top', () async {
        final old = 'n${count - 1}';
        repo.save(note(old, base.add(const Duration(minutes: 1))));
        await pumpEventQueue();

        expect(visibleIds(bloc).first, old);
        expectInSync(bloc, repo);
      });

      test('DeleteNotes removes only the deleted notes', () async {
        bloc.add(DeleteNotes(noteIds: ['n1', 'n2', 'n3']));
        await pumpEventQueue();

        expect(bloc.state.notes, hasLength(count - 3));
        expect(visibleIds(bloc), isNot(contains('n2')));
        expectInSync(bloc, repo);
      });

      test('pinning and unpinning an older note updates the list', () async {
        final old = 'n${count - 1}';
        bloc.add(TogglePinNote(noteId: old));
        await pumpEventQueue();
        expect(visibleIds(bloc).first, old);
        expect(categories(bloc).first, TimeCategory.pinned);

        // Unpinned elsewhere (e.g. from the editor) without editing it
        await repo.togglePinNote(old);
        await pumpEventQueue();
        expect(categories(bloc), isNot(contains(TimeCategory.pinned)));
        expect(visibleIds(bloc).last, old);
        expectInSync(bloc, repo);
      });

      test('a burst of changes ends in a consistent list', () async {
        for (var i = 0; i < 5; i++) {
          repo.save(note('burst$i', base.add(Duration(minutes: i + 1))));
        }
        repo.remove('n0');
        repo.save(note('n5', base.add(const Duration(minutes: 10))));
        await repo.togglePinNote('n${count - 1}');
        await pumpEventQueue();

        expect(
          visibleIds(bloc).toSet(),
          hasLength(visibleIds(bloc).length),
          reason: 'no duplicates',
        );
        expectInSync(bloc, repo);
      });
    });
  }

  group('DeleteNotes', () {
    setUp(() async {
      repo = FakeNoteRepository(notesSpacedBy3h(5));
      bloc = buildBloc(repo);
      await pumpEventQueue();
    });

    test('deletes the selected notes when no ids are given', () async {
      bloc
        ..add(ToggleNoteSelection(noteId: 'n0'))
        ..add(ToggleNoteSelection(noteId: 'n1'))
        ..add(DeleteNotes());
      await pumpEventQueue();

      expect(repo.deletedBatches, [
        ['n0', 'n1'],
      ]);
      expect(bloc.state.selectedNotes, isEmpty);
      expect(bloc.state.isSelectionMode, isFalse);
      expectInSync(bloc, repo);
    });

    test('explicit ids win over the current selection', () async {
      bloc
        ..add(ToggleNoteSelection(noteId: 'n0'))
        ..add(DeleteNotes(noteIds: ['n4']));
      await pumpEventQueue();

      expect(repo.deletedBatches, [
        ['n4'],
      ]);
    });

    test('does nothing when there is nothing to delete', () async {
      bloc.add(DeleteNotes());
      await pumpEventQueue();

      expect(repo.deletedBatches, isEmpty);
    });

    test('reports failedToDeleteNotes when the repository throws', () async {
      repo.deleteError = Exception('disk');
      bloc.add(DeleteNotes(noteIds: ['n0']));
      await pumpEventQueue();

      expect(bloc.state.error, ErrorCategory.failedToDeleteNotes);
    });
  });

  group('selection', () {
    setUp(() async {
      repo = FakeNoteRepository(notesSpacedBy3h(30));
      bloc = buildBloc(repo);
      await pumpEventQueue();
    });

    test('ToggleSelectionMode toggles and clears the selection', () async {
      bloc
        ..add(ToggleNoteSelection(noteId: 'n0'))
        ..add(ToggleSelectionMode());
      await pumpEventQueue();

      expect(bloc.state.isSelectionMode, isFalse);
      expect(bloc.state.selectedNotes, isEmpty);
    });

    test(
      'ToggleNoteSelection adds, removes and enters selection mode',
      () async {
        bloc.add(ToggleNoteSelection(noteId: 'n0'));
        await pumpEventQueue();
        expect(bloc.state.selectedNotes, ['n0']);
        expect(bloc.state.isSelectionMode, isTrue);

        bloc.add(ToggleNoteSelection(noteId: 'n0'));
        await pumpEventQueue();
        expect(bloc.state.selectedNotes, isEmpty);
      },
    );

    test('SelectAllNotes selects every note, then toggles off', () async {
      bloc.add(SelectAllNotes());
      await pumpEventQueue();
      expect(bloc.state.selectedNotes, hasLength(30));

      bloc.add(SelectAllNotes());
      await pumpEventQueue();
      expect(bloc.state.selectedNotes, isEmpty);
      expect(bloc.state.isSelectionMode, isFalse);
    });

    test('ClearSelection resets selection', () async {
      bloc
        ..add(ToggleNoteSelection(noteId: 'n0'))
        ..add(ClearSelection());
      await pumpEventQueue();

      expect(bloc.state.selectedNotes, isEmpty);
      expect(bloc.state.isSelectionMode, isFalse);
    });

    test('a note deleted elsewhere drops out of the selection', () async {
      bloc
        ..add(ToggleNoteSelection(noteId: 'n0'))
        ..add(ToggleNoteSelection(noteId: 'n1'));
      await pumpEventQueue();

      repo.remove('n0');
      await pumpEventQueue();

      expect(bloc.state.selectedNotes, ['n1']);
    });
  });

  group('NotesState', () {
    test('defaults to loading with no notes', () {
      const state = NotesState();
      expect(state.isLoading, isTrue);
      expect(state.notes, isEmpty);
      expect(state.localized, 'en');
    });

    test('copyWith keeps unspecified fields and clears error', () {
      const state = NotesState(
        isLoading: false,
        error: ErrorCategory.failedToLoadNotes,
        selectedNotes: ['a'],
      );
      final copy = state.copyWith(isSelectionMode: true);

      expect(copy.isLoading, isFalse);
      expect(copy.selectedNotes, ['a']);
      expect(copy.isSelectionMode, isTrue);
      expect(copy.error, isNull);
    });

    test('states with equal values are equal', () {
      expect(const NotesState(), const NotesState());
      expect(const NotesState(), isNot(const NotesState(isLoading: false)));
    });
  });
}
