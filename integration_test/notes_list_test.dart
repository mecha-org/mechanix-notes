import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/utils/icons.dart';

import 'test_helper.dart';

void main() {
  setUpIntegrationTests();

  appTest('fresh app shows the title and the empty message', (tester) async {
    expect(find.text('NOTES'), findsOneWidget);
    expect(find.text('Write a note'), findsOneWidget);
    expect(addButton, findsOneWidget);
  });

  appTest('a new note is listed under Recent', (tester) async {
    await createNote(tester, 'Groceries\nmilk, eggs');

    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('milk, eggs'), findsOneWidget);
    final recent = tester.getTopLeft(find.text('Recent')).dy;
    expect(recent, lessThan(tester.getTopLeft(find.text('Groceries')).dy));
  });

  appTest('pin from the editor menu moves the note to Pinned', (tester) async {
    await createNote(tester, 'Older note\nbody');
    await createNote(tester, 'Newer note\nbody');
    expect(find.text('Pinned'), findsNothing);

    await openNote(tester, 'Older note');
    await openEditorMenu(tester);
    await tester.tap(find.text('Pin note'));
    await tester.pump(const Duration(milliseconds: 500));
    await tapEditorBack(tester);

    expect(find.text('Pinned'), findsOneWidget);
    final older = tester.getTopLeft(find.text('Older note')).dy;
    final newer = tester.getTopLeft(find.text('Newer note')).dy;
    expect(older, lessThan(newer)); // pinned notes come first

    final notes = await savedNotes();
    expect(notes.firstWhere((n) => n.title == 'Older note').isPinned, isTrue);
  });

  appTest('pin and unpin with the swipe action', (tester) async {
    await createNote(tester, 'Swipe me\nbody');
    final id = (await savedNotes()).single.id;

    await swipeNoteTile(tester, id);
    await tester.tap(find.byKey(ValueKey('pin_action_$id')));
    await waitFor(tester, find.text('Pinned'));
    expect((await savedNotes()).single.isPinned, isTrue);

    await swipeNoteTile(tester, id);
    await tester.tap(find.byKey(ValueKey('pin_action_$id')));
    await waitUntilGone(tester, find.text('Pinned'));
    expect((await savedNotes()).single.isPinned, isFalse);
  });

  appTest('tapping a group header collapses and expands it', (tester) async {
    await createNote(tester, 'Hidden later\nbody');

    await tester.tap(find.text('Recent'));
    await waitUntilGone(tester, find.text('Hidden later'));

    await tester.tap(find.text('Recent'));
    await waitFor(tester, find.text('Hidden later'));
  });

  appTest('the editor menu shows Unpin for a pinned note', (tester) async {
    await createNote(tester, 'Pinned one\nbody');
    final id = (await savedNotes()).single.id;
    await swipeNoteTile(tester, id);
    await tester.tap(find.byKey(ValueKey('pin_action_$id')));
    await waitFor(tester, find.text('Pinned'));
    await tester.pump(const Duration(milliseconds: 500));

    await openNote(tester, 'Pinned one');
    await openEditorMenu(tester);
    expect(find.text('Unpin note'), findsOneWidget);
    expect(imageAsset(NotesIcon.pinIcon), findsWidgets);
  });
}
