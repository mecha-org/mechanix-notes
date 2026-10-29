import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/utils/constants.dart';

import 'test_helper.dart';

void main() {
  setUpIntegrationTests();

  appTest('very long title is saved in full', (tester) async {
    final longTitle = List.filled(30, 'Longword').join(' '); // ~270 chars
    await createNote(tester, '$longTitle\nbody');

    expect(find.text(longTitle), findsOneWidget);
    expect((await savedNotes()).single.title, longTitle);
  });

  appTest('very long content is saved in full, preview is capped', (
    tester,
  ) async {
    final body = List.generate(2000, (i) => 'word$i').join(' ');
    await createNote(tester, 'Big note\n$body');

    final meta = (await savedNotes()).single;
    expect(
      meta.previewText.length,
      lessThanOrEqualTo(Constants.notePreviewTextMaxLength),
    );
    final saved = await savedNote(meta.id);
    expect(saved!.content, 'Big note\n$body');

    await openNote(tester, 'Big note');
    expect(editorText(tester), 'Big note\n$body');
  });

  appTest('unicode and special characters', (tester) async {
    const title = 'Café ☕ naïve "quotes" / back\\slash: 日本語';
    await createNote(tester, '$title\nemoji 🎉 body');

    expect(find.text(title), findsOneWidget);
    final saved = await savedNote((await savedNotes()).single.id);
    expect(saved!.title, title);
    expect(saved.content, '$title\nemoji 🎉 body');
  });

  appTest('whitespace-only note is discarded', (tester) async {
    await openNewNote(tester);
    await typeInEditor(tester, '   \n   \n');
    await tapEditorBack(tester);

    expect(find.text('Write a note'), findsOneWidget);
    expect(await savedNotes(), isEmpty);
  });

  appTest('rapid open and close does not create notes', (tester) async {
    for (var i = 0; i < 5; i++) {
      await openNewNote(tester);
      await tapEditorBack(tester);
    }
    expect(find.text('Write a note'), findsOneWidget);
    expect(await savedNotes(), isEmpty);
  });

  appTest('two notes with the same title are both kept', (tester) async {
    await createNote(tester, 'Same title\nfirst body');
    await createNote(tester, 'Same title\nsecond body');

    expect(find.text('Same title'), findsNWidgets(2));
    final notes = await savedNotes();
    expect(notes, hasLength(2));
    final contents = [for (final n in notes) (await savedNote(n.id))!.content];
    expect(
      contents,
      unorderedEquals(['Same title\nfirst body', 'Same title\nsecond body']),
    );
  });
}
