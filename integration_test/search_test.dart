import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_bloc.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/search/search_list_view.dart';

import 'notes_test_app.dart';

/// The search screen, on titles and note bodies.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const seed = [
    SeedNote('Grocery list.md', '# Grocery list\napples\n'),
    SeedNote('Grocery budget.md', '# Grocery budget\nweekly\n'),
    SeedNote('Workout.md', '# Workout\nrun 5k\n'),
  ];

  group('Search', () {
    testWidgets('with no notes nothing is found', (tester) async {
      final app = await NotesTestApp.launch(tester);
      await app.openSearch();

      await app.search('anything');

      await app.waitFor(find.text('No note found'));
      expect(app.searchResults, findsNothing);
    });

    testWidgets('opens with an empty, focused field and no results', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester, seed: seed);
      await app.openSearch();

      expect(find.text('SEARCH NOTE'), findsOneWidget);
      expect(app.searchResults, findsNothing);
      expect(find.text('No note found'), findsNothing);
      expect(
        tester.widget<TextField>(app.searchField).focusNode!.hasFocus,
        isTrue,
      );
    });

    testWidgets('finds a note by its title', (tester) async {
      final app = await NotesTestApp.launch(tester, seed: seed);
      await app.openSearch();

      await app.search('Workout');

      await app.waitForSearchResults({'Workout'});
      expect(app.searchResultTitles, ['Workout']);
    });

    testWidgets('queries shorter than 3 characters do not search', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester, seed: seed);
      await app.openSearch();

      await app.search('Wo');
      await app.pumpFor(const Duration(milliseconds: 500));
      expect(app.searchResults, findsNothing);
      expect(find.text('No note found'), findsNothing);

      await app.search('Wor');
      await app.waitForSearchResults({'Workout'});
    });

    testWidgets('is case insensitive', (tester) async {
      final app = await NotesTestApp.launch(tester, seed: seed);
      await app.openSearch();

      await app.search('wORKout');

      await app.waitForSearchResults({'Workout'});
    });

    testWidgets('says so when nothing matches', (tester) async {
      final app = await NotesTestApp.launch(tester, seed: seed);
      await app.openSearch();

      await app.search('zzzzqqq');

      await app.waitFor(find.text('No note found'));
      expect(app.searchResults, findsNothing);
    });

    testWidgets('the clear button empties the query and the results', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester, seed: seed);
      await app.openSearch();
      await app.search('Grocery');
      await app.waitForSearchResults({'Grocery list'});

      await tester.tap(NotesTestApp.button(NotesIcon.closeIcon));
      await app.pumpFor(const Duration(milliseconds: 300));

      expect(find.text('Grocery'), findsNothing);
      expect(app.searchResults, findsNothing);
      // Still on the search screen.
      expect(find.text('SEARCH NOTE'), findsOneWidget);
    });

    testWidgets('close on an empty query, and back, return home', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester, seed: seed);

      await app.openSearch();
      await tester.tap(NotesTestApp.button(NotesIcon.closeIcon));
      await app.waitForAbsent(app.searchField, reason: 'search screen');
      expect(app.createButton, findsOneWidget);

      await app.openSearch();
      await app.search('Grocery');
      await app.closeSearch();
      expect(app.noteCard('Workout'), findsOneWidget);
    });

    testWidgets('opens a note from the results and comes back to them', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester, seed: seed);
      await app.openSearch();
      await app.search('Workout');
      await app.waitForSearchResults({'Workout'});

      await tester.tap(app.searchResults.first);
      await app.waitForEditor();
      expect(app.editorController.text, '# Workout\nrun 5k\n');

      await app.goBack();
      expect(find.text('Workout'), findsWidgets); // the query is kept
      await app.waitForSearchResults({'Workout'});
    });

    testWidgets('shows every matching note', (tester) async {
      final app = await NotesTestApp.launch(tester, seed: seed);
      await app.openSearch();

      await app.search('Grocery');

      await app.waitForSearchResults({'Grocery list', 'Grocery budget'});
      expect(app.searchResultTitles, hasLength(2));
      expect(app.searchResultTitles, isNot(contains('Workout')));
    });
  });

  /// Words drawn in the highlight colour in [title]'s result snippet.
  List<String> highlightedSnippetWords(WidgetTester tester, String title) {
    final tile = find.byWidgetPredicate(
      (w) => w is SearchResultTile && w.note.title == title,
    );
    final primary = Theme.of(tester.element(tile)).colorScheme.primary;
    final texts = tester
        .widgetList<RichText>(
          find.descendant(of: tile, matching: find.byType(RichText)),
        )
        .toList();
    expect(texts.length, greaterThan(1), reason: 'result has no snippet');
    final words = <String>[];
    texts[1].text.visitChildren((span) {
      if (span is TextSpan && span.style?.color == primary) {
        words.add(span.text ?? '');
      }
      return true;
    });
    return words;
  }

  SearchBloc searchBloc(WidgetTester tester) =>
      BlocProvider.of<SearchBloc>(tester.element(find.byType(SearchListView)));

  group('Search on note content', () {
    testWidgets('a word only in the body finds the note', (tester) async {
      final app = await NotesTestApp.launch(
        tester,
        seed: const [
          SeedNote('Garden.md', '# Garden\nplant tomatoes in spring\n'),
          SeedNote('Kitchen.md', '# Kitchen\nfix the tap\n'),
        ],
      );
      await app.openSearch();

      await app.search('tomatoes');

      await app.waitForSearchResults({'Garden'});
      expect(app.searchResultTitles, ['Garden']);
    });

    testWidgets('the result shows a snippet with the match highlighted', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(
        tester,
        seed: const [
          SeedNote(
            'Trip.md',
            '# Trip\npack the passport and the charger before leaving\n',
          ),
        ],
      );
      await app.openSearch();

      await app.search('passport');
      await app.waitForSearchResults({'Trip'});

      expect(app.searchSnippet('Trip'), contains('passport'));
      expect(
        highlightedSnippetWords(tester, 'Trip').map((w) => w.toLowerCase()),
        contains('passport'),
      );
    });

    testWidgets('editing a note in the app updates what search finds', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(
        tester,
        seed: const [SeedNote('Ideas.md', '# Ideas\nbuild a boat\n')],
      );

      await app.openNote('Ideas');
      await app.setText('# Ideas\nbuild a kite');
      await app.goBack();
      await app.waitForFile('Ideas.md', matches: (c) => c.contains('kite'));

      await app.openSearch();
      await app.search('kite');
      await app.waitForSearchResults({'Ideas'});

      await app.search('boat');
      await app.pumpUntil(
        () => app.searchResultTitles.isEmpty,
        reason: 'old body text no longer found',
      );
    });

    testWidgets('a note deleted while results are shown disappears from them', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(
        tester,
        seed: const [
          SeedNote('Red.md', '# Red\nshared colour word\n'),
          SeedNote('Blue.md', '# Blue\nshared colour word\n'),
        ],
      );
      await app.openSearch();
      await app.search('colour');
      await app.waitForSearchResults({'Red', 'Blue'});

      app.file('Red.md').deleteSync();

      await app.pumpUntil(
        () => app.searchResultTitles.length == 1,
        reason: 'Red removed from the results',
      );
      expect(app.searchResultTitles, ['Blue']);
    });

    testWidgets('scrolling to the end loads more results', (tester) async {
      final seed = [
        for (var i = 1; i <= 26; i++)
          SeedNote(
            'Bulk ${i.toString().padLeft(2, '0')}.md',
            '# Bulk ${i.toString().padLeft(2, '0')}\ncommon keyword here\n',
          ),
      ];
      final app = await NotesTestApp.launch(tester, seed: seed);
      await app.openSearch();
      await app.search('keyword');
      await app.waitFor(find.byType(SearchListView));
      await app.pumpUntil(
        () => searchBloc(tester).state.results.isNotEmpty,
        reason: 'first page of results',
      );

      final first = searchBloc(tester).state;
      expect(first.resultIds, hasLength(26));
      expect(first.results, hasLength(20)); // one page
      expect(first.hasMore, isTrue);

      await tester.fling(
        find.byType(SearchListView),
        const Offset(0, -3000),
        3000,
      );
      await app.pumpUntil(
        () => searchBloc(tester).state.results.length == 26,
        reason: 'second page of results',
      );
      expect(searchBloc(tester).state.hasMore, isFalse);
    });
  });
}
