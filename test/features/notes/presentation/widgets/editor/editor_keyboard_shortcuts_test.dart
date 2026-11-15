import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart';
import 'package:mechanix_notes/features/notes/bloc/editor/editor_bloc.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_content.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/markdown_controller_provider.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:widgets/widgets.dart';

class MockEditorBloc extends Mock implements EditorBloc {}

/// Keyboard shortcuts available while editing a note.
///
/// The shortcuts come from the `live_markdown_editor` package; these tests
/// mount the app's own [EditorContent] so they cover what users actually get.
void main() {
  late MockEditorBloc editorBloc;
  late MarkdownEditorController controller;
  late FocusNode focusNode;
  String? clipboard;

  setUp(() {
    editorBloc = MockEditorBloc();
    when(() => editorBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => editorBloc.state).thenReturn(
      const EditorLoaded(
        noteId: 'note-1',
        title: 'Note',
        markdownContent: '',
        isNewNote: false,
        isContentLoading: false,
      ),
    );
    focusNode = FocusNode();
    clipboard = null;
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  void mockClipboard(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clipboard = (call.arguments as Map)['text'] as String?;
            return null;
          case 'Clipboard.getData':
            return clipboard == null ? null : {'text': clipboard};
          case 'Clipboard.hasStrings':
            return {'value': clipboard != null};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  /// Mounts the editor with [text], places the selection and focuses it.
  Future<void> pumpEditor(
    WidgetTester tester,
    String text, {
    required TextSelection selection,
  }) async {
    mockClipboard(tester);
    controller = MarkdownEditorController(text: text);
    await tester.pumpWidget(
      MaterialApp(
        theme: MechanixTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<EditorBloc>.value(
            value: editorBloc,
            child: MarkdownControllerProvider(
              controller: controller,
              focusNode: focusNode,
              child: const EditorContent(),
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    controller.selection = selection;
    await tester.pump();
    // Unmount at the end so the 2s autosave timer is cancelled.
    addTearDown(() => tester.pumpWidget(const SizedBox()));
  }

  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool control = false,
    bool shift = false,
    bool meta = false,
  }) async {
    final modifiers = [
      if (control) LogicalKeyboardKey.controlLeft,
      if (meta) LogicalKeyboardKey.metaLeft,
      if (shift) LogicalKeyboardKey.shiftLeft,
    ];
    for (final m in modifiers) {
      await tester.sendKeyDownEvent(m);
    }
    await tester.sendKeyEvent(key);
    for (final m in modifiers.reversed) {
      await tester.sendKeyUpEvent(m);
    }
    await tester.pump();
  }

  TextSelection sel(int base, [int? extent]) =>
      TextSelection(baseOffset: base, extentOffset: extent ?? base);

  group('Clipboard and selection', () {
    testWidgets('Ctrl+A selects all text', (tester) async {
      await pumpEditor(tester, 'hello world', selection: sel(3));
      await press(tester, LogicalKeyboardKey.keyA, control: true);
      expect(controller.selection.start, 0);
      expect(controller.selection.end, 'hello world'.length);
    });

    testWidgets('Cmd+A (meta) also selects all text', (tester) async {
      await pumpEditor(tester, 'hello world', selection: sel(3));
      await press(tester, LogicalKeyboardKey.keyA, meta: true);
      expect(controller.selection.start, 0);
      expect(controller.selection.end, 'hello world'.length);
    });

    testWidgets('Ctrl+C copies the selection', (tester) async {
      await pumpEditor(tester, 'hello world', selection: sel(0, 5));
      await press(tester, LogicalKeyboardKey.keyC, control: true);
      expect(clipboard, 'hello');
      expect(controller.text, 'hello world');
    });

    testWidgets('Ctrl+X cuts the selection', (tester) async {
      await pumpEditor(tester, 'hello world', selection: sel(5, 11));
      await press(tester, LogicalKeyboardKey.keyX, control: true);
      await tester.pump();
      expect(clipboard, ' world');
      expect(controller.text, 'hello');
    });

    testWidgets('Ctrl+V pastes at the caret', (tester) async {
      await pumpEditor(tester, 'hello', selection: sel(5));
      clipboard = ' there';
      await press(tester, LogicalKeyboardKey.keyV, control: true);
      await tester.pump();
      expect(controller.text, 'hello there');
    });
  });

  group('Undo and redo', () {
    testWidgets('Ctrl+Z undoes and Ctrl+Y redoes', (tester) async {
      await pumpEditor(tester, 'abc', selection: sel(3));
      await press(tester, LogicalKeyboardKey.backspace);
      expect(controller.text, 'ab');

      await press(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(controller.text, 'abc');

      await press(tester, LogicalKeyboardKey.keyY, control: true);
      expect(controller.text, 'ab');
    });

    testWidgets(
      'Ctrl+Shift+Z redoes',
      (tester) async {
        await pumpEditor(tester, 'abc', selection: sel(3));
        await press(tester, LogicalKeyboardKey.backspace);
        await press(tester, LogicalKeyboardKey.keyZ, control: true);
        expect(controller.text, 'abc');

        await press(
          tester,
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        );
        expect(controller.text, 'ab');
      },
      // Known bug in live_markdown_editor: markdown_editable_text.dart's key
      // handler ignores Shift on Ctrl+Z, so Ctrl+Shift+Z undoes instead of
      // redoing. Remove this skip once the package is fixed.
      skip: true,
    );
  });

  group('Editing keys', () {
    testWidgets('Backspace deletes the character before the caret', (
      tester,
    ) async {
      await pumpEditor(tester, 'abc', selection: sel(3));
      await press(tester, LogicalKeyboardKey.backspace);
      expect(controller.text, 'ab');
      expect(controller.selection, const TextSelection.collapsed(offset: 2));
    });

    testWidgets('Delete removes the character after the caret', (tester) async {
      await pumpEditor(tester, 'abc', selection: sel(0));
      await press(tester, LogicalKeyboardKey.delete);
      expect(controller.text, 'bc');
    });

    testWidgets('Backspace removes a whole selection', (tester) async {
      await pumpEditor(tester, 'hello world', selection: sel(5, 11));
      await press(tester, LogicalKeyboardKey.backspace);
      expect(controller.text, 'hello');
    });

    testWidgets('Enter inserts a new line', (tester) async {
      await pumpEditor(tester, 'abc', selection: sel(3));
      await press(tester, LogicalKeyboardKey.enter);
      expect(controller.text, 'abc\n');
    });

    testWidgets('Ctrl+Enter does not insert a new line', (tester) async {
      await pumpEditor(tester, 'abc', selection: sel(3));
      await press(tester, LogicalKeyboardKey.enter, control: true);
      expect(controller.text, 'abc');
    });

    testWidgets('Tab indents a list item and Shift+Tab unindents it', (
      tester,
    ) async {
      const text = '- one\n- two';
      await pumpEditor(tester, text, selection: sel(text.length));

      await press(tester, LogicalKeyboardKey.tab);
      final indented = controller.text;
      expect(indented, isNot(text));
      expect(indented.split('\n').last, matches(RegExp(r'^\s+- two$')));

      await press(tester, LogicalKeyboardKey.tab, shift: true);
      expect(controller.text, text);
    });
  });

  group('Caret movement', () {
    testWidgets('Left and Right arrows move the caret', (tester) async {
      await pumpEditor(tester, 'abc', selection: sel(1));
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(controller.selection, const TextSelection.collapsed(offset: 2));
      await press(tester, LogicalKeyboardKey.arrowLeft);
      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(controller.selection, const TextSelection.collapsed(offset: 0));
    });

    testWidgets('Shift+Right extends the selection', (tester) async {
      await pumpEditor(tester, 'abc', selection: sel(0));
      await press(tester, LogicalKeyboardKey.arrowRight, shift: true);
      await press(tester, LogicalKeyboardKey.arrowRight, shift: true);
      expect(controller.selection.baseOffset, 0);
      expect(controller.selection.extentOffset, 2);
    });

    testWidgets('Shift+Left extends the selection backwards', (tester) async {
      await pumpEditor(tester, 'abc', selection: sel(3));
      await press(tester, LogicalKeyboardKey.arrowLeft, shift: true);
      await press(tester, LogicalKeyboardKey.arrowLeft, shift: true);
      expect(controller.selection.baseOffset, 3);
      expect(controller.selection.extentOffset, 1);
    });

    testWidgets('Shift+Up extends the selection to the previous line', (
      tester,
    ) async {
      await pumpEditor(tester, 'first line\nsecond line', selection: sel(15));
      await press(tester, LogicalKeyboardKey.arrowUp, shift: true);
      expect(controller.selection, sel(15, 4));
    });

    testWidgets('Shift+Up moves past a heading line', (tester) async {
      await pumpEditor(tester, '# Title\nbody text', selection: sel(12));
      await press(tester, LogicalKeyboardKey.arrowUp, shift: true);
      expect(controller.selection.baseOffset, 12);
      expect(controller.selection.extentOffset, lessThan(8));
    });

    testWidgets('Up moves past a heading line', (tester) async {
      await pumpEditor(tester, '# Title\nbody text', selection: sel(12));
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.extentOffset, lessThan(8));
    });

    testWidgets('Shift+Up on the first line selects to the start', (
      tester,
    ) async {
      await pumpEditor(tester, 'only line here', selection: sel(6));
      await press(tester, LogicalKeyboardKey.arrowUp, shift: true);
      expect(controller.selection, sel(6, 0));
    });

    testWidgets('Shift+Down on the last line selects to the end', (
      tester,
    ) async {
      await pumpEditor(tester, 'only line here', selection: sel(6));
      await press(tester, LogicalKeyboardKey.arrowDown, shift: true);
      expect(controller.selection, sel(6, 14));
    });

    testWidgets('Shift+Up keeps the column across a blank line', (
      tester,
    ) async {
      await pumpEditor(
        tester,
        'first para\n\nsecond para',
        selection: sel(17),
      );
      // Shift is released and pressed again between steps, as users do.
      await press(tester, LogicalKeyboardKey.arrowUp, shift: true);
      await press(tester, LogicalKeyboardKey.arrowUp, shift: true);
      expect(controller.selection, sel(17, 5));
    });

    // flutter-elinux's text input plugin also moves the caret on Left/Right,
    // ignoring Shift, and pushes the collapsed caret back to the framework.
    // That echo must not undo the selection the editor just made.
    for (final (name, key, expected) in [
      ('Left', LogicalKeyboardKey.arrowLeft, 1),
      ('Right', LogicalKeyboardKey.arrowRight, 5),
    ]) {
      testWidgets('Shift+$name survives the eLinux embedder caret echo', (
        tester,
      ) async {
        await pumpEditor(tester, 'abcdef', selection: sel(3));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        for (var i = 0; i < 2; i++) {
          await tester.sendKeyEvent(key);
          final caret = controller.selection.extentOffset;
          tester.testTextInput.updateEditingValue(
            TextEditingValue(
              text: controller.text,
              selection: TextSelection.collapsed(offset: caret),
            ),
          );
          await tester.pump();
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(controller.selection, sel(3, expected));
      });
    }

    testWidgets('Down and Up arrows move between lines', (tester) async {
      await pumpEditor(tester, 'abc\ndef', selection: sel(1));
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(controller.selection.extentOffset, 5);
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(controller.selection.extentOffset, 1);
    });

    testWidgets('Shift+Down extends the selection to the next line', (
      tester,
    ) async {
      await pumpEditor(tester, 'abc\ndef', selection: sel(1));
      await press(tester, LogicalKeyboardKey.arrowDown, shift: true);
      expect(controller.selection.baseOffset, 1);
      expect(controller.selection.extentOffset, 5);
    });
  });

  group('Formatting', () {
    testWidgets('Ctrl+B wraps the selection in bold markers', (tester) async {
      await pumpEditor(tester, 'make this bold', selection: sel(10, 14));
      await press(tester, LogicalKeyboardKey.keyB, control: true);
      expect(controller.text, 'make this **bold**');
      expect(controller.selection, sel(12, 16));
    });

    testWidgets('Ctrl+B with no selection inserts a bold pair at the caret', (
      tester,
    ) async {
      await pumpEditor(tester, 'ab', selection: sel(1));
      await press(tester, LogicalKeyboardKey.keyB, control: true);
      expect(controller.text, 'a****b');
      expect(controller.selection, sel(3));
    });

    testWidgets('Ctrl+I wraps the selection in italic markers', (tester) async {
      await pumpEditor(tester, 'make this italic', selection: sel(10, 16));
      await press(tester, LogicalKeyboardKey.keyI, control: true);
      expect(controller.text, 'make this *italic*');
      expect(controller.selection, sel(11, 17));
    });

    testWidgets('Cmd+B and Cmd+I (meta) also format', (tester) async {
      await pumpEditor(tester, 'x', selection: sel(0, 1));
      await press(tester, LogicalKeyboardKey.keyB, meta: true);
      expect(controller.text, '**x**');
      await press(tester, LogicalKeyboardKey.keyI, meta: true);
      expect(controller.text, '***x***');
    });

    testWidgets('Ctrl+B can be undone with Ctrl+Z', (tester) async {
      await pumpEditor(tester, 'word', selection: sel(0, 4));
      await press(tester, LogicalKeyboardKey.keyB, control: true);
      expect(controller.text, '**word**');
      await press(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(controller.text, 'word');
    });
  });

  group('Escape', () {
    testWidgets('Esc leaves text and selection alone', (tester) async {
      await pumpEditor(tester, 'abc', selection: sel(0, 2));
      await press(tester, LogicalKeyboardKey.escape);
      expect(controller.text, 'abc');
      expect(controller.selection, sel(0, 2));
    });
  });

  group('Checklist', () {
    testWidgets('Space toggles a focused checklist checkbox', (tester) async {
      await pumpEditor(tester, '- [ ] task', selection: sel(10));
      final checkbox = find.byType(MechanixCheckbox);
      expect(checkbox, findsOneWidget);

      Focus.of(tester.element(find.byType(Checkbox))).requestFocus();
      await tester.pump();
      await press(tester, LogicalKeyboardKey.space);
      expect(controller.text, '- [x] task');
    });
  });
}
