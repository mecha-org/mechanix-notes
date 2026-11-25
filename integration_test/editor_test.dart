import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:widgets/widgets.dart';

import 'notes_test_app.dart';

/// The note editor: Markdown formatting (checked in the editor text and in
/// the saved `.md` file), keyboard shortcuts, text selection and deleting.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Saves the note by going back and returns the file's content.
  Future<String> saveAndRead(NotesTestApp app, String fileName) async {
    await app.goBack();
    return app.waitForFile(fileName);
  }

  group('Inline formatting', () {
    testWidgets('bold wraps the selection in ** and tapping again removes it', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();
      await app.setText('# Bold note\nmake this word stand out');

      await app.selectText('word');
      await app.tapToolbar(NotesTestApp.boldButton);
      expect(
        app.editorController.text,
        '# Bold note\nmake this **word** stand out',
      );

      await app.selectText('word');
      expect(app.isToolbarActive(NotesTestApp.boldButton), isTrue);
      await app.tapToolbar(NotesTestApp.boldButton);
      expect(
        app.editorController.text,
        '# Bold note\nmake this word stand out',
      );

      await app.selectText('stand');
      await app.tapToolbar(NotesTestApp.boldButton);
      expect(
        await saveAndRead(app, 'Bold note.md'),
        '# Bold note\nmake this word **stand** out\n',
      );
    });

    testWidgets('italic wraps the selection in single *', (tester) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();
      await app.setText('# Italic note\nsay it softly');

      await app.selectText('softly');
      await app.tapToolbar(NotesTestApp.italicButton);

      expect(app.editorController.text, '# Italic note\nsay it *softly*');
      expect(app.isToolbarActive(NotesTestApp.italicButton), isTrue);
      expect(
        await saveAndRead(app, 'Italic note.md'),
        '# Italic note\nsay it *softly*\n',
      );
    });

    testWidgets('bold and italic together give ***text***', (tester) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();
      await app.setText('# Both\nvery important');

      await app.selectText('important');
      await app.tapToolbar(NotesTestApp.boldButton);
      await app.selectText('important');
      await app.tapToolbar(NotesTestApp.italicButton);

      expect(app.editorController.text, '# Both\nvery ***important***');
      await app.selectText('important');
      expect(app.isToolbarActive(NotesTestApp.boldButton), isTrue);
      expect(app.isToolbarActive(NotesTestApp.italicButton), isTrue);
      expect(
        await saveAndRead(app, 'Both.md'),
        '# Both\nvery ***important***\n',
      );
    });

    // The toolbar has no underline button (not implemented); strikethrough
    // is the remaining inline style.
    testWidgets('strikethrough wraps the selection in ~~', (tester) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();
      await app.setText('# Done\nold plan');

      await app.selectText('old');
      await app.tapToolbar(NotesTestApp.strikethroughButton);

      expect(app.editorController.text, '# Done\n~~old~~ plan');
      expect(await saveAndRead(app, 'Done.md'), '# Done\n~~old~~ plan\n');
    });

    testWidgets('formats only the selected part of a line', (tester) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();
      await app.setText('# Partial\nalpha beta gamma');

      await app.selectText('beta');
      await app.tapToolbar(NotesTestApp.boldButton);

      expect(app.editorController.text, '# Partial\nalpha **beta** gamma');
    });

    testWidgets('toolbar shows the style under the caret', (tester) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();
      await app.setText('# State\nplain **strong** *soft* tail');

      await app.placeCaretAfter('stro');
      expect(app.isToolbarActive(NotesTestApp.boldButton), isTrue);
      expect(app.isToolbarActive(NotesTestApp.italicButton), isFalse);

      await app.placeCaretAfter('so');
      expect(app.isToolbarActive(NotesTestApp.boldButton), isFalse);
      expect(app.isToolbarActive(NotesTestApp.italicButton), isTrue);

      await app.placeCaretAfter('tai');
      expect(app.isToolbarActive(NotesTestApp.boldButton), isFalse);
      expect(app.isToolbarActive(NotesTestApp.italicButton), isFalse);
      expect(app.isToolbarActive(NotesTestApp.bodyButton), isTrue);
    });
  });

  group('Block formatting', () {
    testWidgets('H1 and H2 replace each other and toggle off', (tester) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();
      await app.setText('# Headings\nSection');

      await app.tapToolbar(NotesTestApp.h2Button);
      expect(app.editorController.text, '# Headings\n## Section');
      expect(app.isToolbarActive(NotesTestApp.h2Button), isTrue);

      await app.tapToolbar(NotesTestApp.h1Button);
      expect(app.editorController.text, '# Headings\n# Section');
      expect(app.isToolbarActive(NotesTestApp.h1Button), isTrue);
      expect(app.isToolbarActive(NotesTestApp.h2Button), isFalse);

      await app.tapToolbar(NotesTestApp.h1Button);
      expect(app.editorController.text, '# Headings\nSection');

      await app.tapToolbar(NotesTestApp.h2Button);
      await app.tapToolbar(NotesTestApp.bodyButton);
      expect(app.editorController.text, '# Headings\nSection');
      expect(app.isToolbarActive(NotesTestApp.bodyButton), isTrue);

      await app.tapToolbar(NotesTestApp.h2Button);
      expect(await saveAndRead(app, 'Headings.md'), '# Headings\n## Section\n');
    });

    testWidgets('Enter continues a bullet list and ends it on an empty item', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();
      await app.setText('# List\n- one');
      await app.focusEditor();

      await app.pressKey(LogicalKeyboardKey.enter);
      expect(app.editorController.text, '# List\n- one\n- ');

      await app.setText('# List\n- one\n- two');
      await app.pressKey(LogicalKeyboardKey.enter);
      expect(app.editorController.text, '# List\n- one\n- two\n- ');

      await app.pressKey(LogicalKeyboardKey.enter);
      expect(app.editorController.text, '# List\n- one\n- two\n');

      expect(await saveAndRead(app, 'List.md'), '# List\n- one\n- two\n');
    });

    testWidgets('checklist button adds a task that can be ticked', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();
      await app.setText('# Tasks\nbuy milk');

      await app.tapToolbar(NotesTestApp.checklistButton);
      expect(app.editorController.text, '# Tasks\n- [ ] buy milk');
      expect(app.isToolbarActive(NotesTestApp.checklistButton), isTrue);

      await app.waitFor(find.byType(MechanixCheckbox));
      await tester.tap(find.byType(MechanixCheckbox));
      await tester.pump();
      expect(app.editorController.text, '# Tasks\n- [x] buy milk');

      expect(await saveAndRead(app, 'Tasks.md'), '# Tasks\n- [x] buy milk\n');
    });

    testWidgets('code button fences the line and tapping again unwraps it', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();
      await app.setText('# Snippet\nprint(1)');

      await app.tapToolbar(NotesTestApp.codeButton);
      expect(app.editorController.text, '# Snippet\n```\nprint(1)\n```\n');
      expect(app.isToolbarActive(NotesTestApp.codeButton), isTrue);

      await app.tapToolbar(NotesTestApp.codeButton);
      expect(app.editorController.text, '# Snippet\nprint(1)\n');

      await app.placeCaretAfter('print(1)');
      await app.tapToolbar(NotesTestApp.codeButton);
      expect(
        await saveAndRead(app, 'Snippet.md'),
        '# Snippet\n```\nprint(1)\n```\n',
      );
    });
  });

  group('Saved formatting', () {
    testWidgets('reopening a saved note shows the same markdown and styles', (
      tester,
    ) async {
      const doc =
          '# Recipe\n'
          '## Steps\n'
          'mix **flour** and *water*\n'
          '- [x] preheat\n'
          '- [ ] bake\n'
          '```\ntimer 20\n```';
      final app = await NotesTestApp.launch(tester);
      await app.createNoteWith(doc);
      expect(await app.waitForFile('Recipe.md'), '$doc\n');

      await app.openNote('Recipe');
      expect(app.editorController.text, '$doc\n');

      await app.placeCaretAfter('flo');
      expect(app.isToolbarActive(NotesTestApp.boldButton), isTrue);
      await app.placeCaretAfter('wat');
      expect(app.isToolbarActive(NotesTestApp.italicButton), isTrue);
      await app.placeCaretAfter('Ste');
      expect(app.isToolbarActive(NotesTestApp.h2Button), isTrue);

      final checkboxes = tester
          .widgetList<MechanixCheckbox>(find.byType(MechanixCheckbox))
          .map((c) => c.value)
          .toList();
      expect(checkboxes, [true, false]);
    });

    testWidgets('a markdown file written outside the app opens correctly', (
      tester,
    ) async {
      const content =
          '# External **title**\n'
          'body with *style*\n'
          '- [ ] open item\n';
      final app = await NotesTestApp.launch(
        tester,
        seed: [const SeedNote('external.md', content)],
      );

      // The title is shown without its markdown.
      await app.waitForNoteCard('External title');
      await app.openNote('External title');

      expect(app.editorController.text, content);
      expect(find.byType(MechanixCheckbox), findsOneWidget);
      await app.placeCaretAfter('sty');
      expect(app.isToolbarActive(NotesTestApp.italicButton), isTrue);
    });
  });

  group('Undo and redo', () {
    testWidgets('undo removes formatting and redo restores it', (tester) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();
      await app.setText('# Undo note\nword');

      await app.selectText('word');
      await app.tapToolbar(NotesTestApp.boldButton);
      expect(app.editorController.text, '# Undo note\n**word**');

      await tester.tap(NotesTestApp.button(NotesIcon.undoIcon));
      await tester.pump();
      expect(app.editorController.text, '# Undo note\nword');

      await tester.tap(NotesTestApp.button(NotesIcon.redoIcon));
      await tester.pump();
      expect(app.editorController.text, '# Undo note\n**word**');

      expect(await saveAndRead(app, 'Undo note.md'), '# Undo note\n**word**\n');
    });
  });

  group('Toolbar modes', () {
    testWidgets('the mode toggle swaps the buttons shown', (tester) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();

      const textButtons = [
        NotesTestApp.h1Button,
        NotesTestApp.h2Button,
        NotesTestApp.bodyButton,
        NotesTestApp.boldButton,
        NotesTestApp.italicButton,
        NotesTestApp.strikethroughButton,
      ];
      const linkButtons = [
        NotesTestApp.codeButton,
        NotesTestApp.checklistButton,
      ];

      for (final b in textButtons) {
        expect(find.byKey(b), findsOneWidget);
      }
      for (final b in linkButtons) {
        expect(find.byKey(b), findsNothing);
      }

      await tester.tap(find.byKey(NotesTestApp.linkModeToggle));
      await tester.pump();
      for (final b in textButtons) {
        expect(find.byKey(b), findsNothing);
      }
      for (final b in linkButtons) {
        expect(find.byKey(b), findsOneWidget);
      }

      await tester.tap(find.byKey(NotesTestApp.textModeToggle));
      await tester.pump();
      expect(find.byKey(NotesTestApp.boldButton), findsOneWidget);
      expect(find.byKey(NotesTestApp.codeButton), findsNothing);
    });

    testWidgets('the checklist button turns a task back into plain text', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();
      await app.setText('# Chores\n- [ ] sweep');

      await app.tapToolbar(NotesTestApp.checklistButton);

      expect(app.editorController.text, '# Chores\nsweep');
      expect(app.isToolbarActive(NotesTestApp.checklistButton), isFalse);
    });

    testWidgets('the code button on an empty line opens an empty block', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();
      await app.setText('# Script\n');

      await app.tapToolbar(NotesTestApp.codeButton);

      expect(app.editorController.text, '# Script\n```\n\n```\n');
      // The caret is inside the block, so typing goes there.
      final caret = app.editorController.selection.baseOffset;
      expect(caret, '# Script\n```\n'.length);
      expect(app.isToolbarActive(NotesTestApp.codeButton), isTrue);
    });
  });

  group('Keyboard shortcuts', () {
    testWidgets('Ctrl+B and Ctrl+I make the selection bold and italic', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();
      await app.setText('# Keys\nloud quiet');
      await app.focusEditor();

      await app.selectText('loud');
      await app.pressKey(LogicalKeyboardKey.keyB, control: true);
      expect(app.editorController.text, '# Keys\n**loud** quiet');

      await app.selectText('quiet');
      await app.pressKey(LogicalKeyboardKey.keyI, control: true);
      expect(app.editorController.text, '# Keys\n**loud** *quiet*');

      await app.goBack();
      expect(await app.waitForFile('Keys.md'), '# Keys\n**loud** *quiet*\n');
    });

    testWidgets('Esc in the editor saves the note and returns home', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();
      await app.setText('# Escaped\nsaved by escape');
      await app.focusEditor();

      await app.pressKey(LogicalKeyboardKey.escape);

      await app.waitForAbsent(app.editor, reason: 'editor');
      await app.waitForNoteCard('Escaped');
      expect(
        await app.waitForFile('Escaped.md'),
        '# Escaped\nsaved by escape\n',
      );
    });

    testWidgets('Esc on the search screen returns home with a query typed', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(
        tester,
        seed: const [SeedNote('Some note.md', '# Some note\n')],
      );
      await app.openSearch();
      await app.search('some');
      expect(find.text('some'), findsOneWidget);

      await app.pressKey(LogicalKeyboardKey.escape);

      await app.waitForAbsent(app.searchField, reason: 'search screen');
      expect(app.createButton, findsOneWidget);
      expect(app.noteCard('Some note'), findsOneWidget);
    });

    testWidgets('arrow keys with Shift and Ctrl select in the search field', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester);
      await app.openSearch();
      await app.search('hello brave world');
      final controller = tester.widget<TextField>(app.searchField).controller!;
      controller.selection = const TextSelection.collapsed(offset: 17);
      await tester.pump();

      // Ctrl+Shift+Left selects the previous word.
      await app.pressKey(
        LogicalKeyboardKey.arrowLeft,
        control: true,
        shift: true,
      );
      expect(controller.selection.textInside(controller.text), 'world');

      // Shift+Left extends it by one character.
      await app.pressKey(LogicalKeyboardKey.arrowLeft, shift: true);
      expect(controller.selection.textInside(controller.text), ' world');

      // Ctrl+Left moves to the start of the previous word, no selection.
      await app.pressKey(LogicalKeyboardKey.arrowLeft, control: true);
      expect(controller.selection, const TextSelection.collapsed(offset: 6));

      // Shift+Down selects to the end.
      await app.pressKey(LogicalKeyboardKey.arrowDown, shift: true);
      expect(controller.selection.textInside(controller.text), 'brave world');

      // Shift+Up from there selects to the start.
      await app.pressKey(LogicalKeyboardKey.arrowUp, shift: true);
      expect(controller.selection.textInside(controller.text), 'hello ');
    });
  });

  group('Text selection', () {
    testWidgets('double-tapping a word in a note selects it with handles', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(
        tester,
        seed: const [SeedNote('Words.md', '# Words\nalpha bravo charlie\n')],
      );
      await app.openNote('Words');

      final render = tester
          .state<MarkdownEditableTextState>(find.byType(MarkdownEditableText))
          .renderEditable!;
      final bravo = app.editorController.text.indexOf('bravo') + 2;
      final target = render.localToGlobal(
        render.getLocalRectForCaret(TextPosition(offset: bravo)).center,
      );

      await tester.tapAt(target, kind: PointerDeviceKind.touch);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(target, kind: PointerDeviceKind.touch);
      await app.pumpFor(const Duration(milliseconds: 300));

      final controller = app.editorController;
      expect(controller.selection.textInside(controller.text), 'bravo');
      expect(
        find.byKey(const ValueKey('markdown-selection-handle-start')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('markdown-selection-handle-end')),
        findsOneWidget,
      );

      // Leaving the note with the word still selected.
      await app.goBack();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the search field menu offers paste and select all', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester);
      await app.openSearch();
      await app.search('find me');
      final controller = tester.widget<TextField>(app.searchField).controller!;

      // Right-click opens the menu; nothing is selected yet, so there is no
      // Cut or Copy.
      await tester.tapAt(
        tester.getCenter(app.searchField),
        buttons: kSecondaryButton,
        kind: PointerDeviceKind.mouse,
      );
      await app.pumpFor(const Duration(milliseconds: 300));
      expect(find.text('Paste'), findsOneWidget);
      expect(find.text('Select all'), findsOneWidget);
      expect(find.text('Cut'), findsNothing);
      expect(find.text('Copy'), findsNothing);

      await tester.tap(find.text('Select all'));
      await app.pumpFor(const Duration(milliseconds: 300));
      expect(controller.selection.textInside(controller.text), 'find me');
    });
  });

  const seed = [
    SeedNote('Draft.md', '# Draft\nthrow away\n'),
    SeedNote('Keeper.md', '# Keeper\nkeep this\n'),
  ];

  group('Delete from the editor', () {
    testWidgets('confirming deletes the file and returns home', (tester) async {
      final app = await NotesTestApp.launch(tester, seed: seed);
      await app.openNote('Draft');

      await app.tapEditorMenuItem('Delete');
      expect(find.text('Do you want to delete this note?'), findsOneWidget);
      await tester.tap(find.text('DELETE'));

      await app.waitForAbsent(app.editor, reason: 'editor');
      await app.waitForAbsent(app.noteCard('Draft'));
      await app.waitForFileGone('Draft.md');
      expect(app.homeTitles, ['Keeper']);
      expect(app.noteFiles, ['Keeper.md']);
    });

    testWidgets('cancelling keeps the note and stays in the editor', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester, seed: seed);
      await app.openNote('Draft');

      await app.tapEditorMenuItem('Delete');
      await tester.tap(find.text('CANCEL'));
      await app.pumpFor(const Duration(milliseconds: 500));

      expect(find.text('Do you want to delete this note?'), findsNothing);
      expect(app.editor, findsOneWidget);
      expect(app.editorController.text, '# Draft\nthrow away\n');

      await app.goBack();
      expect(app.noteCard('Draft'), findsOneWidget);
      expect(app.file('Draft.md').existsSync(), isTrue);
    });
  });
}
