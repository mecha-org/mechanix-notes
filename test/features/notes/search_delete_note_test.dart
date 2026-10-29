import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/utils/app_routes.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:mechanix_notes/features/notes/presentation/screens/editor.dart';
import 'package:mechanix_notes/features/notes/presentation/screens/search.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';
import 'package:widgets/widgets.dart';

/// In-memory [NoteRepository]. Deletes stay pending until [finishDeletes] is
/// called, like the real file + DB + index delete still running after the
/// editor has closed.
class FakeNoteRepository implements NoteRepository {
  FakeNoteRepository(List<NoteModel> notes)
    : _notes = {for (final n in notes) n.id: n};

  final Map<String, NoteModel> _notes;
  final _changes = StreamController<List<NoteMetaData>>.broadcast();
  final _pendingDelete = Completer<void>();
  final List<String> deleteRequests = [];

  void finishDeletes() => _pendingDelete.complete();

  NoteMetaData _toMetaData(NoteModel n) => NoteMetaData(
    id: n.id,
    title: n.title,
    createdAt: n.createdAt,
    updatedAt: n.updatedAt,
    previewText: n.previewText,
    height: n.height,
    isPinned: n.isPinned,
  );

  List<NoteMetaData> get _all => _notes.values.map(_toMetaData).toList();

  @override
  Stream<List<NoteMetaData>> watchNotes() async* {
    yield _all;
    yield* _changes.stream;
  }

  @override
  Future<NoteModel?> getNoteById(String id) async => _notes[id];

  @override
  Future<void> deleteNotes(List<String> ids) async {
    deleteRequests.addAll(ids);
    await _pendingDelete.future;
    ids.forEach(_notes.remove);
    _changes.add(_all);
  }

  @override
  Future<void> upsertNote(NoteModel note) async {
    _notes[note.id] = note;
    _changes.add(_all);
  }

  @override
  Future<List<String>> searchNoteIds(String query) async => [
    for (final n in _notes.values)
      if (n.title.toLowerCase().contains(query.toLowerCase())) n.id,
  ];

  @override
  Future<List<NoteMetaData>> getNotesMetaData(List<String> ids) async => [
    for (final id in ids)
      if (_notes[id] case final note?) _toMetaData(note),
  ];

  @override
  Future<bool> togglePinNote(String id) async => false;

  @override
  Future<void> close() async => _changes.close();
}

NoteModel _note(String id, String title) {
  final now = DateTime.now();
  return NoteModel(
    id: id,
    title: title,
    content: '# $title\n\nSome body text',
    createdAt: now,
    updatedAt: now,
    plainText: '$title Some body text',
    previewText: 'Some body text',
    height: 0,
  );
}

/// The app's real search and editor screens, with routes registered the same
/// way as in main.dart.
Widget _buildApp(FakeNoteRepository repository) {
  return RepositoryProvider<NoteRepository>.value(
    value: repository,
    child: BlocProvider(
      create: (context) => NotesBloc(noteRepository: repository),
      child: MechanixTheme(
        builder: (context, theme, child) => MaterialApp(
          theme: theme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SearchScreen(),
          routes: {AppRoutes.noteEditor: (context) => const EditorScreen()},
        ),
      ),
    ),
  );
}

/// The search screen's only text field.
Finder get _searchField => find.byType(TextField);

Finder _resultCard(String title) => find.text(title, findRichText: true);

Finder _asset(String asset) => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName == asset,
);

/// Pumps frames for [duration] without waiting for animations to stop,
/// because the editor's cursor blinks forever.
Future<void> _settle(
  WidgetTester tester, [
  Duration duration = const Duration(seconds: 1),
]) async {
  for (var i = 0; i < duration.inMilliseconds ~/ 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(_searchField, query);
  await _settle(tester);
}

Future<void> _openResult(WidgetTester tester, String title) async {
  await tester.tap(_resultCard(title));
  await _settle(tester);
}

void main() {
  late FakeNoteRepository repository;

  setUp(() {
    repository = FakeNoteRepository([
      _note('1', 'Groceries list'),
      _note('2', 'Groceries budget'),
    ]);
  });

  testWidgets('tapping a search result opens the note in the editor', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(repository));
    await _search(tester, 'groceries');

    await _openResult(tester, 'Groceries list');

    expect(tester.takeException(), isNull);
    expect(find.byType(EditorScreen), findsOneWidget);
  });

  testWidgets(
    'trashing a note from search removes its card while the delete is '
    'still running',
    (tester) async {
      await tester.pumpWidget(_buildApp(repository));
      await _search(tester, 'groceries');
      await _openResult(tester, 'Groceries list');

      await tester.tap(_asset(NotesIcon.moreVertIcon));
      await _settle(tester);
      await tester.tap(find.text('Delete'));
      await _settle(tester);
      await tester.tap(find.text('DELETE'));
      await _settle(tester);

      // Back on search with the delete not finished yet
      expect(find.byType(EditorScreen), findsNothing);
      expect(repository.deleteRequests, ['1']);
      expect(_resultCard('Groceries list'), findsNothing);
      expect(_resultCard('Groceries budget'), findsOneWidget);

      repository.finishDeletes();
      await _settle(tester);

      expect(_resultCard('Groceries list'), findsNothing);
      expect(_resultCard('Groceries budget'), findsOneWidget);
    },
  );

  testWidgets('closing the editor without deleting keeps the card', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(repository));
    await _search(tester, 'groceries');
    await _openResult(tester, 'Groceries list');

    await tester.tap(_asset(NotesIcon.backIcon));
    await _settle(tester);

    expect(find.byType(EditorScreen), findsNothing);
    expect(repository.deleteRequests, isEmpty);
    expect(_resultCard('Groceries list'), findsOneWidget);
    expect(_resultCard('Groceries budget'), findsOneWidget);
  });
}
