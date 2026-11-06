import 'package:flutter_test/flutter_test.dart';

import 'test_helper.dart';

void main() {
  setUpIntegrationTests();

  appTest('opens with an empty, focused search box', (tester) async {
    await openSearch(tester);

    expect(find.text('SEARCH NOTE'), findsOneWidget); // hint
    expect(find.text('No note found'), findsNothing);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  appTest('with no notes, a search finds nothing', (tester) async {
    await openSearch(tester);
    await searchFor(tester, 'anything');

    expect(find.text('No note found'), findsOneWidget);
  });

  appTest('finds a note by title', (tester) async {
    await createNote(tester, 'Daily Journal\nToday was calm.');
    await createNote(tester, 'Shopping\nbread and butter');

    await openSearch(tester);
    await searchFor(tester, 'Journal');

    expect(searchResult('Daily Journal'), findsOneWidget);
    expect(searchResult('Shopping'), findsNothing);
  });

  appTest('finds a note by body text', (tester) async {
    await createNote(tester, 'Daily Journal\nToday was calm.');
    await createNote(tester, 'Shopping\nbread and butter');

    await openSearch(tester);
    await searchFor(tester, 'butter');

    expect(searchResult('Shopping'), findsOneWidget);
    expect(searchResult('Daily Journal'), findsNothing);
  });

  appTest('search ignores case', (tester) async {
    await createNote(tester, 'Daily Journal\nToday was calm.');

    await openSearch(tester);
    await searchFor(tester, 'dAiLy');

    expect(searchResult('Daily Journal'), findsOneWidget);
  });

  appTest('shows a message when nothing matches', (tester) async {
    await createNote(tester, 'Daily Journal\nToday was calm.');

    await openSearch(tester);
    await searchFor(tester, 'zzzz');

    expect(find.text('No note found'), findsOneWidget);
    expect(searchResult('Daily Journal'), findsNothing);
  });

  appTest('X clears the query, a second X closes search', (tester) async {
    await createNote(tester, 'Daily Journal\nToday was calm.');

    await openSearch(tester);
    await searchFor(tester, 'Daily');
    expect(searchResult('Daily Journal'), findsOneWidget);

    await tapSearchClose(tester);
    expect(find.text('SEARCH NOTE'), findsOneWidget); // empty again
    expect(searchResult('Daily Journal'), findsNothing);

    await tapSearchClose(tester);
    await waitForHome(tester);
    expect(searchField, findsNothing);
  });

  appTest('shows every matching note', (tester) async {
    await createNote(tester, 'Project alpha\nkickoff');
    await createNote(tester, 'Project beta\nreview');
    await createNote(tester, 'Holiday\nbeach');

    await openSearch(tester);
    await searchFor(tester, 'Project');

    expect(searchResult('Project alpha'), findsOneWidget);
    expect(searchResult('Project beta'), findsOneWidget);
    expect(searchResult('Holiday'), findsNothing);
  });

  appTest('open a result, edit it, and come back to updated results', (
    tester,
  ) async {
    await createNote(tester, 'Daily Journal\nToday was calm.');

    await openSearch(tester);
    await searchFor(tester, 'Daily');
    await tester.tap(searchResult('Daily Journal'));
    await waitForEditor(tester);
    expect(editorText(tester), 'Daily Journal\nToday was calm.');

    await typeInEditor(tester, 'Daily Journal\nToday was busy.');
    await tester.tap(imageAsset('assets/icons/back.png'));
    await waitFor(tester, searchField.hitTestable());
    await tester.pump(const Duration(seconds: 1));

    // Back on search, with the query kept and the new preview shown.
    expect(find.text('Daily'), findsOneWidget);
    expect(searchResult('Today was busy.'), findsOneWidget);
  });

  appTest('a note deleted from a result disappears from results', (
    tester,
  ) async {
    await createNote(tester, 'Daily Journal\nToday was calm.');
    await createNote(tester, 'Daily Plan\nwork, gym');

    await openSearch(tester);
    await searchFor(tester, 'Daily');
    expect(searchResult('Daily Journal'), findsOneWidget);
    expect(searchResult('Daily Plan'), findsOneWidget);

    await tester.tap(searchResult('Daily Journal'));
    await waitForEditor(tester);
    await openEditorMenu(tester);
    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 500));
    await confirmDelete(tester);
    await waitFor(tester, searchField.hitTestable());
    await tester.pump(const Duration(seconds: 1));

    expect(searchResult('Daily Journal'), findsNothing);
    expect(searchResult('Daily Plan'), findsOneWidget);
  });
}
