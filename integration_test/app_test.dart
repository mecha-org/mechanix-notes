import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/utils/icons.dart';

import 'test_helper.dart';

/// One full user journey through the app.
void main() {
  setUpIntegrationTests();

  appTest('create, format, pin, search, edit and delete a note', (
    tester,
  ) async {
    expect(find.text('Write a note'), findsOneWidget);

    // Create with a bold word from the toolbar.
    await openNewNote(tester);
    await typeInEditor(tester, 'Weekly plan\nfinish report');
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Weekly plan\nfinish report',
        selection: TextSelection(baseOffset: 12, extentOffset: 18),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(imageAsset(NotesIcon.boldIcon).last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(editorText(tester), 'Weekly plan\n**finish** report');

    // Pin it, then go back: it is saved and shown under Pinned.
    await openEditorMenu(tester);
    await tester.tap(find.text('Pin note'));
    await tester.pump(const Duration(milliseconds: 500));
    await tapEditorBack(tester);
    expect(find.text('Pinned'), findsOneWidget);
    expect(find.text('Weekly plan'), findsOneWidget);
    expect(find.text('finish report'), findsOneWidget); // preview, no **

    // Find it with search and edit it from there.
    await openSearch(tester);
    await searchFor(tester, 'report');
    await tester.tap(searchResult('Weekly plan'));
    await waitForEditor(tester);
    await typeInEditor(tester, 'Weekly plan\n**finish** report\ncall Sam');
    await tester.tap(imageAsset(NotesIcon.backIcon));
    await waitFor(tester, searchField.hitTestable());
    await tapSearchClose(tester); // clear query
    await tapSearchClose(tester); // close search
    await waitForHome(tester);

    final note = (await savedNotes()).single;
    expect(note.isPinned, isTrue);
    expect((await savedNote(note.id))!.content, contains('call Sam'));

    // Delete it from the editor.
    await openNote(tester, 'Weekly plan');
    await openEditorMenu(tester);
    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 500));
    await confirmDelete(tester);
    await waitForHome(tester);

    expect(find.text('Write a note'), findsOneWidget);
    expect(await savedNotes(), isEmpty);
  });
}
