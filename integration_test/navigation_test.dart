import 'package:flutter_test/flutter_test.dart';

import 'test_helper.dart';

void main() {
  setUpIntegrationTests();

  appTest('open a note shows its content; back without changes keeps it', (
    tester,
  ) async {
    await createNote(tester, 'Recipe\nAdd salt.');
    final before = (await savedNotes()).single;

    await openNote(tester, 'Recipe');
    expect(editorText(tester), 'Recipe\nAdd salt.');

    await tapEditorBack(tester);
    expect(find.text('Recipe'), findsOneWidget);
    final after = (await savedNotes()).single;
    expect(after.updatedAt, before.updatedAt); // nothing was rewritten
  });

  appTest('edit then back saves the change', (tester) async {
    await createNote(tester, 'Recipe\nAdd salt.');

    await openNote(tester, 'Recipe');
    await typeInEditor(tester, 'Recipe\nAdd pepper.');
    await tapEditorBack(tester);

    expect(find.text('Add pepper.'), findsOneWidget);
    expect(find.text('Add salt.'), findsNothing);
    expect(await savedNotes(), hasLength(1));
  });

  appTest('system back from the editor saves the note', (tester) async {
    await openNewNote(tester);
    await typeInEditor(tester, 'System back\nstill saved');

    await tester.binding.handlePopRoute();
    await waitForHome(tester);

    expect(find.text('System back'), findsOneWidget);
    expect(await savedNotes(), hasLength(1));
  });

  appTest('home -> search -> home', (tester) async {
    await openSearch(tester);
    expect(find.text('SEARCH NOTE'), findsOneWidget);

    await tapSearchClose(tester); // empty query: X closes search
    await waitForHome(tester);
    expect(searchField, findsNothing);
  });
}
