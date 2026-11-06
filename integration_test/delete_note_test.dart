import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helper.dart';

void main() {
  setUpIntegrationTests();

  appTest('delete from the editor menu', (tester) async {
    await createNote(tester, 'Delete me\nbody');

    await openNote(tester, 'Delete me');
    await openEditorMenu(tester);
    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Do you want to delete this note?'), findsOneWidget);
    await confirmDelete(tester);
    await waitForHome(tester);

    expect(find.text('Delete me'), findsNothing);
    expect(find.text('Write a note'), findsOneWidget);
    expect(await savedNotes(), isEmpty);
  });

  appTest('cancel in the delete sheet keeps the note', (tester) async {
    await createNote(tester, 'Keep me\nbody');

    await openNote(tester, 'Keep me');
    await openEditorMenu(tester);
    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 500));
    await cancelDelete(tester);
    await waitUntilGone(tester, find.text('Do you want to delete this note?'));

    expect(editor, findsOneWidget); // still in the editor
    await tapEditorBack(tester);
    expect(find.text('Keep me'), findsOneWidget);
    expect(await savedNotes(), hasLength(1));
  });

  appTest('delete a new, unsaved note from the editor menu', (tester) async {
    await openNewNote(tester);
    await typeInEditor(tester, 'Never kept\nbody');
    await openEditorMenu(tester);
    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 500));
    await confirmDelete(tester);
    await waitForHome(tester);

    expect(find.text('Never kept'), findsNothing);
    expect(await savedNotes(), isEmpty);
  });

  appTest('delete with the swipe action on home', (tester) async {
    await createNote(tester, 'Swipe delete\nbody');
    await createNote(tester, 'Stays\nbody');
    final id = (await savedNotes())
        .firstWhere((n) => n.title == 'Swipe delete')
        .id;

    await swipeNoteTile(tester, id);
    await tester.tap(find.byKey(ValueKey('delete_action_$id')));
    await tester.pump(const Duration(milliseconds: 500));
    await confirmDelete(tester);
    await waitUntilGone(tester, find.text('Swipe delete'));

    expect(find.text('Stays'), findsOneWidget);
    final notes = await savedNotes();
    expect(notes.map((n) => n.title), ['Stays']);
  });

  appTest('cancel the swipe delete keeps the note', (tester) async {
    await createNote(tester, 'Swipe keep\nbody');
    final id = (await savedNotes()).single.id;

    await swipeNoteTile(tester, id);
    await tester.tap(find.byKey(ValueKey('delete_action_$id')));
    await tester.pump(const Duration(milliseconds: 500));
    await cancelDelete(tester);

    expect(find.text('Swipe keep'), findsOneWidget);
    expect(await savedNotes(), hasLength(1));
  });
}
