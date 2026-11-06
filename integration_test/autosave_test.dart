import 'package:flutter_test/flutter_test.dart';

import 'test_helper.dart';

// The editor saves on its own 2 seconds after the last change.
void main() {
  setUpIntegrationTests();

  appTest('does not save before 2 seconds, saves after', (tester) async {
    await openNewNote(tester);
    await typeInEditor(tester, 'Draft\nfirst words');

    await tester.pump(const Duration(seconds: 1));
    expect(await savedNotes(), isEmpty);

    await tester.pump(const Duration(milliseconds: 1500));
    final notes = await savedNotes();
    expect(notes, hasLength(1));
    expect(notes.single.title, 'Draft');
    expect(notes.single.previewText, 'first words');
  });

  appTest('continuous typing delays the save until typing stops', (
    tester,
  ) async {
    await openNewNote(tester);
    await typeInEditor(tester, 'Part 1');

    // Each change comes before the 2 s timer runs out, so it restarts.
    for (final text in ['Part 1 and 2', 'Part 1 and 2 and 3']) {
      await tester.pump(const Duration(milliseconds: 1000));
      tester.testTextInput.enterText(text);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(milliseconds: 1000));
    expect(await savedNotes(), isEmpty);

    await tester.pump(const Duration(milliseconds: 1500));
    final notes = await savedNotes();
    expect(notes, hasLength(1));
    expect(notes.single.title, 'Part 1 and 2 and 3');
  });

  appTest('later autosaves update the same note', (tester) async {
    await openNewNote(tester);
    await typeInEditor(tester, 'Version one\nbody one');
    await tester.pump(const Duration(milliseconds: 2500));
    final first = await savedNotes();
    expect(first, hasLength(1));

    tester.testTextInput.enterText('Version two\nbody two');
    await tester.pump(const Duration(milliseconds: 2500));
    final second = await savedNotes();
    expect(second, hasLength(1));
    expect(second.single.id, first.single.id);
    expect(second.single.title, 'Version two');

    await tapEditorBack(tester);
    expect(find.text('Version two'), findsOneWidget);
    expect(find.text('Version one'), findsNothing);
    expect(await savedNotes(), hasLength(1));
  });

  appTest('back right after typing saves without waiting', (tester) async {
    await openNewNote(tester);
    await typeInEditor(tester, 'Quick note\nsaved on back');
    await tapEditorBack(tester); // well before the 2 s autosave

    expect(find.text('Quick note'), findsOneWidget);
    final notes = await savedNotes();
    expect(notes, hasLength(1));
    expect(notes.single.title, 'Quick note');
  });
}
