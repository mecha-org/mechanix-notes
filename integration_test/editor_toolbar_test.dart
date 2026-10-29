import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/utils/icons.dart';

import 'test_helper.dart';

/// Sets the editor text with the caret at the end.
Future<void> setText(WidgetTester tester, String text) async {
  await typeInEditor(tester, text);
}

/// Sets the editor text with [selection] selected, as if dragged with a mouse.
Future<void> setTextWithSelection(
  WidgetTester tester,
  String text,
  TextSelection selection,
) async {
  await typeInEditor(tester, text);
  tester.testTextInput.updateEditingValue(
    TextEditingValue(text: text, selection: selection),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> tapTool(WidgetTester tester, String asset) async {
  await tester.tap(imageAsset(asset).last);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpIntegrationTests();

  appTest('H1, H2 and body style change the current line', (tester) async {
    await openNewNote(tester);
    await setText(tester, 'Hello');

    await tapTool(tester, NotesIcon.h2Icon);
    expect(editorText(tester), '## Hello');

    await tapTool(tester, NotesIcon.h2Icon); // again: back to body
    expect(editorText(tester), 'Hello');

    await tapTool(tester, NotesIcon.h1Icon);
    expect(editorText(tester), '# Hello');

    await tapTool(tester, NotesIcon.textstyleIcon);
    expect(editorText(tester), 'Hello');
  });

  appTest('checklist adds and removes a task box', (tester) async {
    await openNewNote(tester);
    await setText(tester, 'Buy milk');

    await tapTool(tester, NotesIcon.todoIcon);
    expect(editorText(tester), '- [ ] Buy milk');

    await tapTool(tester, NotesIcon.todoIcon);
    expect(editorText(tester), 'Buy milk');
  });

  appTest('bold, italic and strikethrough wrap the selection', (tester) async {
    const word = TextSelection(baseOffset: 0, extentOffset: 5);

    await openNewNote(tester);

    await setTextWithSelection(tester, 'Hello world', word);
    await tapTool(tester, NotesIcon.boldIcon);
    expect(editorText(tester), '**Hello** world');

    await setTextWithSelection(tester, 'Hello world', word);
    await tapTool(tester, NotesIcon.italicIcon);
    expect(editorText(tester), '*Hello* world');

    await setTextWithSelection(tester, 'Hello world', word);
    await tapTool(tester, NotesIcon.strikethroughIcon);
    expect(editorText(tester), '~~Hello~~ world');
  });

  appTest('bold on an already bold selection removes it', (tester) async {
    await openNewNote(tester);
    await setTextWithSelection(
      tester,
      '**Hello** world',
      const TextSelection(baseOffset: 0, extentOffset: 9),
    );
    await tapTool(tester, NotesIcon.boldIcon);
    expect(editorText(tester), 'Hello world');
  });

  appTest('code block inserts a fence', (tester) async {
    await openNewNote(tester);
    await setText(tester, 'Snippet');

    await tapTool(tester, NotesIcon.codeBlockIcon);
    expect(editorText(tester), contains('```'));
  });

  appTest('undo and redo', (tester) async {
    await openNewNote(tester);
    expect(editorController(tester).canUndo, isFalse);

    await setText(tester, 'Hello');
    await tapTool(tester, NotesIcon.h1Icon);
    expect(editorText(tester), '# Hello');

    await tapTool(tester, NotesIcon.undoIcon);
    expect(editorText(tester), 'Hello');
    expect(editorController(tester).canRedo, isTrue);

    await tapTool(tester, NotesIcon.redoIcon);
    expect(editorText(tester), '# Hello');
  });

  appTest('formatting is saved with the note', (tester) async {
    await openNewNote(tester);
    await setTextWithSelection(
      tester,
      'Styled\nsome text',
      const TextSelection(baseOffset: 7, extentOffset: 11),
    );
    await tapTool(tester, NotesIcon.boldIcon);
    expect(editorText(tester), 'Styled\n**some** text');
    await tapEditorBack(tester);

    final saved = await savedNote((await savedNotes()).single.id);
    expect(saved!.title, 'Styled');
    expect(saved.content, 'Styled\n**some** text');

    await openNote(tester, 'Styled');
    expect(editorText(tester), 'Styled\n**some** text');
  });
}
