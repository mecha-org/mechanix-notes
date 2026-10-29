import 'package:flutter_test/flutter_test.dart';

import 'test_helper.dart';

void main() {
  setUpIntegrationTests();

  appTest('empty note is discarded on back', (tester) async {
    expect(find.text('Write a note'), findsOneWidget);

    await openNewNote(tester);
    expect(editorText(tester), '# '); // a new note starts as an empty H1
    await tapEditorBack(tester);

    expect(find.text('Write a note'), findsOneWidget);
    expect(await savedNotes(), isEmpty);
  });

  appTest('single line becomes the title', (tester) async {
    await createNote(tester, 'Shopping list');

    // A one-line note shows the line as title and as preview.
    expect(find.text('Shopping list'), findsWidgets);
    expect(find.text('Write a note'), findsNothing);

    final notes = await savedNotes();
    expect(notes, hasLength(1));
    expect(notes.single.title, 'Shopping list');
  });

  appTest('first line is the title, the rest is the preview', (tester) async {
    await createNote(tester, 'Meeting notes\nDiscuss the release plan.');

    expect(find.text('Meeting notes'), findsOneWidget);
    expect(find.text('Discuss the release plan.'), findsOneWidget);

    final notes = await savedNotes();
    expect(notes, hasLength(1));
    expect(notes.single.title, 'Meeting notes');
    expect(notes.single.previewText, 'Discuss the release plan.');
  });

  appTest('H1 heading becomes the title', (tester) async {
    await createNote(tester, '# Trip ideas\nVisit the mountains.');

    expect(find.text('Trip ideas'), findsOneWidget);
    expect(find.text('Visit the mountains.'), findsOneWidget);

    final saved = await savedNote((await savedNotes()).single.id);
    expect(saved!.title, 'Trip ideas');
    expect(saved.content, '# Trip ideas\nVisit the mountains.');
  });

  appTest('several notes are all listed, newest first', (tester) async {
    await createNote(tester, 'First note\nbody one');
    await createNote(tester, 'Second note\nbody two');
    await createNote(tester, 'Third note\nbody three');

    expect(find.text('First note'), findsOneWidget);
    expect(find.text('Second note'), findsOneWidget);
    expect(find.text('Third note'), findsOneWidget);

    final titles = (await savedNotes()).map((n) => n.title).toList();
    expect(titles, ['Third note', 'Second note', 'First note']);

    // Newest is shown above older ones.
    final third = tester.getTopLeft(find.text('Third note')).dy;
    final first = tester.getTopLeft(find.text('First note')).dy;
    expect(third, lessThan(first));
  });
}
