import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechanix_notes/core/utils/constants.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_note_card.dart';

import 'notes_test_app.dart';

/// Creating, editing and saving notes, and notes as Markdown files on disk.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End to end', () {
    testWidgets('create, format, save, find, pin, edit and delete a note', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester);

      // Create and format.
      await app.createNote();
      await app.setText('# Lifecycle\nan important detail');
      await app.selectText('important');
      await app.tapToolbar(NotesTestApp.boldButton);
      await app.placeCaretAfter('detail');
      await app.tapToolbar(NotesTestApp.checklistButton);
      await app.goBack();

      expect(
        await app.waitForFile('Lifecycle.md'),
        '# Lifecycle\n- [ ] an **important** detail\n',
      );
      await app.waitForNoteCard('Lifecycle');

      // Find it by a word in its body.
      await app.openSearch();
      await app.search('detail');
      await app.waitForSearchResults({'Lifecycle'});
      await app.closeSearch();

      // Pin it from the editor and edit it.
      await app.openNote('Lifecycle');
      await app.tapEditorMenuItem('Pin note');
      await app.setText('# Lifecycle\n- [x] an **important** detail\n');
      await app.goBack();
      await app.pumpUntil(() => app.isPinnedOnHome('Lifecycle'));
      expect(
        await app.waitForFile(
          'Lifecycle.md',
          matches: (c) => c.contains('[x]'),
        ),
        '# Lifecycle\n- [x] an **important** detail\n',
      );

      // Delete it.
      await app.openNote('Lifecycle');
      await app.tapEditorMenuItem('Delete');
      await tester.tap(find.text('DELETE'));
      await app.waitForAbsent(app.editor, reason: 'editor');
      await app.waitFor(find.text('Write a note'));
      await app.waitForFileGone('Lifecycle.md');
      expect(app.noteCard('Lifecycle'), findsNothing);
    });
  });

  String preview(WidgetTester tester, NotesTestApp app, String title) =>
      tester.widget<HomeNoteCard>(app.noteCard(title)).note.previewText;

  group('Create note', () {
    testWidgets('an empty note is discarded', (tester) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();
      expect(app.editorController.text, '# ');

      await app.goBack();

      expect(app.noteFiles, isEmpty);
      expect(find.byType(HomeNoteCard), findsNothing);
      expect(find.text('Write a note'), findsOneWidget);
    });

    testWidgets('a title only', (tester) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNoteWith('# Only a title');

      await app.waitForNoteCard('Only a title');
      expect(preview(tester, app, 'Only a title'), isEmpty);
      expect(await app.waitForFile('Only a title.md'), '# Only a title\n');
    });

    testWidgets('content without a heading uses its first line as title', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();
      await app.setText('first line here\nsecond line here');
      await app.goBack();

      await app.waitForNoteCard('first line here');
      expect(preview(tester, app, 'first line here'), 'second line here');
      expect(
        await app.waitForFile('first line here.md'),
        'first line here\nsecond line here\n',
      );
    });

    testWidgets('a title and content', (tester) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNoteWith('# Meeting\nagenda items\nnext steps');

      await app.waitForNoteCard('Meeting');
      expect(preview(tester, app, 'Meeting'), 'agenda items\nnext steps');
      expect(
        await app.waitForFile('Meeting.md'),
        '# Meeting\nagenda items\nnext steps\n',
      );
    });
  });

  group('Navigation', () {
    testWidgets('opening a note shows its content; back leaves it untouched', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(
        tester,
        seed: [
          SeedNote(
            'Existing.md',
            '# Existing\nwhat was written\n',
            modified: DateTime.now().subtract(const Duration(minutes: 10)),
          ),
        ],
      );
      final before = app.file('Existing.md').lastModifiedSync();

      await app.openNote('Existing');
      expect(app.editorController.text, '# Existing\nwhat was written\n');

      await app.goBack();
      expect(app.createButton, findsOneWidget);
      expect(app.noteCard('Existing'), findsOneWidget);
      // No change, so no save.
      await app.pumpFor(const Duration(milliseconds: 500));
      expect(app.file('Existing.md').lastModifiedSync(), before);
    });

    testWidgets('going back right after typing saves without waiting', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();
      await app.setText('# Hurried\ntyped and left');

      // Well before the 2 s autosave.
      await app.goBack();

      await app.waitForNoteCard('Hurried');
      expect(
        await app.waitForFile('Hurried.md'),
        '# Hurried\ntyped and left\n',
      );
    });
  });

  group('Autosave', () {
    testWidgets('does not save before 2 seconds without typing', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();

      await app.setText('# Quick\nbody');
      await app.pumpFor(const Duration(seconds: 1));
      expect(app.noteFiles, isEmpty);

      await app.waitForFile('Quick.md');
      expect(app.file('Quick.md').readAsStringSync(), '# Quick\nbody\n');
      // Still in the editor: autosave does not close it.
      expect(app.editor, findsOneWidget);
    });

    testWidgets('continuous typing waits until typing stops', (tester) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();

      // Each change comes less than 2 s after the previous one.
      for (final text in [
        '# Typing\none',
        '# Typing\none two',
        '# Typing\none two three',
        '# Typing\none two three four',
      ]) {
        await app.setText(text);
        await app.pumpFor(const Duration(milliseconds: 1200));
        expect(app.noteFiles, isEmpty, reason: 'saved while still typing');
      }

      final saved = await app.waitForFile('Typing.md');
      expect(saved, '# Typing\none two three four\n');
    });

    testWidgets('later edits update the same file', (tester) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();

      await app.setText('# Same note\nfirst version');
      await app.waitForFile(
        'Same note.md',
        matches: (c) => c.contains('first version'),
      );

      await app.setText('# Same note\nsecond version');
      await app.waitForFile(
        'Same note.md',
        matches: (c) => c.contains('second version'),
      );
      expect(app.noteFiles, ['Same note.md']);

      await app.goBack();
      expect(app.homeTitles, ['Same note']);
    });
  });

  group('Edge cases', () {
    testWidgets('a very long title is shortened in the list and file name', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester);
      final longTitle = 'A' * 200;
      await app.createNoteWith('# $longTitle\nbody');

      final shown = 'A' * Constants.noteTitleMaxLength;
      await app.waitForNoteCard(shown);
      // The file is named after the shortened title.
      final fileName = '$shown.md';
      expect(app.noteFiles, [fileName]);
      expect(await app.waitForFile(fileName), '# $longTitle\nbody\n');
      expect(tester.takeException(), isNull);
    });

    testWidgets('very long content is saved whole', (tester) async {
      final app = await NotesTestApp.launch(tester);
      final body = List.generate(500, (i) => 'line $i ${'B' * 60}').join('\n');
      await app.createNoteWith('# Long\n$body');

      expect(await app.waitForFile('Long.md'), '# Long\n$body\n');
      final card = tester.widget<HomeNoteCard>(app.noteCard('Long'));
      expect(card.note.previewText.length, Constants.notePreviewTextMaxLength);

      await app.openNote('Long');
      expect(app.editorController.text, '# Long\n$body\n');
    });

    testWidgets('clearing an existing note deletes it', (tester) async {
      final app = await NotesTestApp.launch(
        tester,
        seed: const [SeedNote('Clear me.md', '# Clear me\nsome text\n')],
      );
      await app.openNote('Clear me');

      await app.setText('');
      await app.goBack();

      await app.waitForAbsent(app.noteCard('Clear me'));
      await app.waitForFileGone('Clear me.md');
      expect(find.text('Write a note'), findsOneWidget);
    });

    testWidgets('notes with the same title get separate files', (tester) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNoteWith('# Twin\nfirst');
      await app.waitForFile('Twin.md');
      await app.createNoteWith('# Twin\nsecond');

      await app.waitForFile('Twin (1).md');
      expect(app.noteFiles, ['Twin (1).md', 'Twin.md']);
      expect(app.file('Twin.md').readAsStringSync(), '# Twin\nfirst\n');
      expect(app.file('Twin (1).md').readAsStringSync(), '# Twin\nsecond\n');
      await app.pumpUntil(() => app.homeTitles.length == 2);
      expect(app.homeTitles, ['Twin', 'Twin']);
    });

    testWidgets('rapidly opening and closing notes leaves nothing behind', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(
        tester,
        seed: const [SeedNote('Steady.md', '# Steady\nunchanged\n')],
      );

      for (var i = 0; i < 3; i++) {
        await app.createNote();
        await app.goBack();
        await app.openNote('Steady');
        await app.goBack();
      }

      expect(app.noteFiles, ['Steady.md']);
      expect(app.file('Steady.md').readAsStringSync(), '# Steady\nunchanged\n');
      expect(app.homeTitles, ['Steady']);
      expect(tester.takeException(), isNull);
    });
  });

  group('Sync with files on disk', () {
    testWidgets('a file created outside the app appears in the list', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester);

      app.writeExternal('From outside.md', '# From outside\nwritten by vim\n');

      await app.waitForNoteCard('From outside');
      final card = tester.widget<HomeNoteCard>(app.noteCard('From outside'));
      expect(card.note.previewText, 'written by vim');
    });

    testWidgets('editing a file outside the app updates the list and search', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(
        tester,
        seed: [const SeedNote('Diary.md', '# Diary\nmorning walk\n')],
      );
      await app.waitForNoteCard('Diary');

      app.writeExternal(
        'Diary.md',
        '# Diary\nevening swim\n',
        modified: DateTime.now().add(const Duration(seconds: 5)),
      );

      await app.pumpUntil(
        () =>
            tester
                .widget<HomeNoteCard>(app.noteCard('Diary'))
                .note
                .previewText ==
            'evening swim',
        reason: 'updated preview',
      );

      await app.openSearch();
      await app.search('swim');
      await app.waitForSearchResults({'Diary'});
      await app.search('walk');
      await app.pumpUntil(
        () => app.searchResultTitles.isEmpty,
        reason: 'old text no longer found',
      );
    });

    testWidgets('deleting a file outside the app removes the note', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(
        tester,
        seed: const [
          SeedNote('Keep.md', '# Keep\n'),
          SeedNote('Remove.md', '# Remove\n'),
        ],
      );
      await app.waitForNoteCard('Remove');

      app.file('Remove.md').deleteSync();

      await app.waitForAbsent(app.noteCard('Remove'));
      expect(app.homeTitles, ['Keep']);

      await app.openSearch();
      await app.search('Remove');
      await app.pumpFor(const Duration(milliseconds: 500));
      expect(app.searchResultTitles, isEmpty);
    });

    testWidgets('renaming a file outside the app keeps the note and its pin', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(
        tester,
        seed: const [SeedNote('Old name.md', '# Project\nplans\n')],
      );
      await app.tapCardAction('Project', pin: true);
      await app.pumpUntil(() => app.isPinnedOnHome('Project'));

      app.file('Old name.md').renameSync('${app.notesDir.path}/New name.md');

      await app.pumpUntil(
        () =>
            tester.widget<HomeNoteCard>(app.noteCard('Project')).note.id ==
            'New name.md',
        reason: 'card to follow the rename',
      );
      expect(app.homeTitles, ['Project']);
      expect(app.isPinnedOnHome('Project'), isTrue);
    });

    testWidgets('hidden, temporary and non-markdown files are ignored', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(
        tester,
        seed: const [SeedNote('Real.md', '# Real\n')],
      );
      await app.waitForNoteCard('Real');

      app.writeExternal('.hidden.md', '# Hidden\n');
      app.writeExternal('..tmp_Real_123.md', '# Temp\n');
      app.writeExternal('todo.txt', '# Text file\n');
      app.writeExternal('image.png', 'not an image');

      // Longer than the watcher's 300 ms debounce.
      await app.pumpFor(const Duration(seconds: 2));
      expect(app.homeTitles, ['Real']);

      // Also ignored by the full rescan done at startup.
      final restarted = await app.restart();
      await restarted.waitForNoteCard('Real');
      expect(restarted.homeTitles, ['Real']);
    });

    testWidgets('changes made while the app was closed show on next start', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(
        tester,
        seed: const [
          SeedNote('Edited.md', '# Edited\nbefore\n'),
          SeedNote('Deleted.md', '# Deleted\n'),
        ],
      );
      await app.waitForNoteCard('Deleted');

      final restarted = await app.restart(
        whileClosed: () {
          app.writeExternal(
            'Edited.md',
            '# Edited\nafter\n',
            modified: DateTime.now().add(const Duration(seconds: 5)),
          );
          app.file('Deleted.md').deleteSync();
          app.writeExternal('Added.md', '# Added\n');
        },
      );

      await restarted.waitForNoteCard('Added');
      await restarted.waitForAbsent(restarted.noteCard('Deleted'));
      expect(
        tester
            .widget<HomeNoteCard>(restarted.noteCard('Edited'))
            .note
            .previewText,
        'after',
      );
    });
  });

  group('Titles', () {
    testWidgets('markdown in the title is not shown in the list or search', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNoteWith('# **Bold** and *styled* title\nbody');

      await app.waitForNoteCard('Bold and styled title');
      expect(find.textContaining('**'), findsNothing);
      expect(find.textContaining('*styled*'), findsNothing);
      expect(app.noteFiles, ['Bold and styled title.md']);

      await app.openSearch();
      await app.search('styled');
      await app.waitForSearchResults({'Bold and styled title'});
    });

    testWidgets('changing the title renames the file and the index entry', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(
        tester,
        seed: const [SeedNote('Draft name.md', '# Draft name\ncontent\n')],
      );

      await app.openNote('Draft name');
      await app.setText('# Final name\ncontent');
      await app.goBack();

      await app.waitForFile('Final name.md');
      await app.waitForFileGone('Draft name.md');
      expect(app.noteFiles, ['Final name.md']);
      await app.waitForNoteCard('Final name');
      expect(app.homeTitles, ['Final name']);

      await app.openSearch();
      await app.search('Final');
      await app.waitForSearchResults({'Final name'});
      await app.search('Draft');
      await app.pumpFor(const Duration(milliseconds: 500));
      expect(app.searchResultTitles, isEmpty);
    });
  });

  group('Persistence', () {
    testWidgets('a saved note is unchanged after the app restarts', (
      tester,
    ) async {
      const doc =
          '# Shopping\n'
          '- [x] **bread**\n'
          '- [ ] *eggs*\n'
          '```\nlist v2\n```';
      var app = await NotesTestApp.launch(tester);
      await app.createNoteWith(doc);
      await app.waitForFile('Shopping.md');
      await app.tapCardAction('Shopping', pin: true);
      await app.pumpUntil(() => app.isPinnedOnHome('Shopping'));

      app = await app.restart();

      await app.waitForNoteCard('Shopping');
      expect(app.isPinnedOnHome('Shopping'), isTrue);
      final card = tester.widget<HomeNoteCard>(app.noteCard('Shopping'));
      expect(card.note.previewText, contains('bread'));
      await app.openNote('Shopping');
      expect(app.editorController.text, '$doc\n');
    });
  });
}
