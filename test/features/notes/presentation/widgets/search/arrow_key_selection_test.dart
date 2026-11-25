import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/search/arrow_key_selection.dart';

/// Arrow-key selection in the single-line search field.
void main() {
  late TextEditingController controller;
  late FocusNode focusNode;

  setUp(() {
    controller = TextEditingController();
    focusNode = FocusNode();
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  Future<void> pumpField(
    WidgetTester tester,
    String text, {
    required int caret,
  }) async {
    controller.text = text;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArrowKeySelection(
            controller: controller,
            child: TextField(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    controller.selection = TextSelection.collapsed(offset: caret);
    await tester.pump();
  }

  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool control = false,
    bool shift = false,
  }) async {
    final modifiers = [
      if (control) LogicalKeyboardKey.controlLeft,
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

  String selected() => controller.selection.textInside(controller.text);

  const text = 'hello brave world';

  testWidgets('Shift+Right and Shift+Left extend by one character', (
    tester,
  ) async {
    await pumpField(tester, text, caret: 6);

    await press(tester, LogicalKeyboardKey.arrowRight, shift: true);
    await press(tester, LogicalKeyboardKey.arrowRight, shift: true);
    expect(selected(), 'br');

    await press(tester, LogicalKeyboardKey.arrowLeft, shift: true);
    expect(selected(), 'b');
    expect(controller.selection.baseOffset, 6);
  });

  testWidgets('Ctrl+Right stops at the end of the word', (tester) async {
    await pumpField(tester, text, caret: 0);

    await press(tester, LogicalKeyboardKey.arrowRight, control: true);
    expect(controller.selection, const TextSelection.collapsed(offset: 5));

    await press(tester, LogicalKeyboardKey.arrowRight, control: true);
    expect(controller.selection, const TextSelection.collapsed(offset: 11));
  });

  testWidgets('Ctrl+Left goes to the start of the previous word', (
    tester,
  ) async {
    await pumpField(tester, text, caret: 17);

    await press(tester, LogicalKeyboardKey.arrowLeft, control: true);
    expect(controller.selection, const TextSelection.collapsed(offset: 12));

    await press(tester, LogicalKeyboardKey.arrowLeft, control: true);
    expect(controller.selection, const TextSelection.collapsed(offset: 6));
  });

  testWidgets('Ctrl+Shift+Left and Right extend by whole words', (
    tester,
  ) async {
    await pumpField(tester, text, caret: 17);

    await press(
      tester,
      LogicalKeyboardKey.arrowLeft,
      control: true,
      shift: true,
    );
    expect(selected(), 'world');

    await pumpField(tester, text, caret: 0);
    await press(
      tester,
      LogicalKeyboardKey.arrowRight,
      control: true,
      shift: true,
    );
    expect(selected(), 'hello');
  });

  testWidgets('Shift+Up and Shift+Down select to the start and end', (
    tester,
  ) async {
    await pumpField(tester, text, caret: 6);

    await press(tester, LogicalKeyboardKey.arrowUp, shift: true);
    expect(selected(), 'hello ');

    await pumpField(tester, text, caret: 6);
    await press(tester, LogicalKeyboardKey.arrowDown, shift: true);
    expect(selected(), 'brave world');
  });

  testWidgets('Ctrl+Up and Ctrl+Down move to the start and end', (
    tester,
  ) async {
    await pumpField(tester, text, caret: 6);

    await press(tester, LogicalKeyboardKey.arrowDown, control: true);
    expect(controller.selection, const TextSelection.collapsed(offset: 17));

    await press(tester, LogicalKeyboardKey.arrowUp, control: true);
    expect(controller.selection, const TextSelection.collapsed(offset: 0));
  });

  testWidgets('a selection overwritten while Shift is held is put back', (
    tester,
  ) async {
    await pumpField(tester, text, caret: 6);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(selected(), 'b');

    // The eLinux embedder echoes its own caret, ignoring Shift.
    controller.selection = const TextSelection.collapsed(offset: 7);
    await tester.pump();
    expect(selected(), 'b');

    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    // Without a modifier held, caret changes are left alone.
    controller.selection = const TextSelection.collapsed(offset: 2);
    await tester.pump();
    expect(controller.selection, const TextSelection.collapsed(offset: 2));
  });

  testWidgets('other Ctrl shortcuts still reach the field (Ctrl+A)', (
    tester,
  ) async {
    await pumpField(tester, text, caret: 17);
    await press(
      tester,
      LogicalKeyboardKey.arrowLeft,
      control: true,
      shift: true,
    );
    expect(selected(), 'world');

    await press(tester, LogicalKeyboardKey.keyA, control: true);

    expect(selected(), text);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
