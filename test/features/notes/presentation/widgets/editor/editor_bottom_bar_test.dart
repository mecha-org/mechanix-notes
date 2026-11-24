import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/bottom_bar/notes_text_link_control.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_bottom_bar.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/markdown_controller_provider.dart';
import 'package:widgets/widgets.dart';

void main() {
  late MarkdownEditorController controller;
  late FocusNode focusNode;

  setUp(() {
    controller = MarkdownEditorController();
    focusNode = FocusNode();
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: MarkdownControllerProvider(
        controller: controller,
        focusNode: focusNode,
        child: const Scaffold(body: Center(child: EditorBottomBar())),
      ),
    );
  }

  group('EditorBottomBar Tests', () {
    testWidgets('renders NotesTextLinkControl in EditorBottomBar', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(NotesTextLinkControl), findsOneWidget);
      expect(find.byKey(const Key('notes_text_toggle')), findsOneWidget);
      expect(
        find.byKey(const Key('notes_text_contextual_button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('notes_link_toggle')), findsOneWidget);
    });

    testWidgets('tapping H1 button toggles Header 1 format on current line', (
      tester,
    ) async {
      controller.value = const TextEditingValue(
        text: 'Hello world',
        selection: TextSelection.collapsed(offset: 5),
      );

      await tester.pumpWidget(buildTestWidget());

      final h1Finder = find.byKey(const Key('notes_text_contextual_button'));
      expect(tester.widget<MechanixIconButton>(h1Finder).isSelected, isFalse);

      // Tap H1 button
      await tester.tap(h1Finder);
      await tester.pumpAndSettle();

      // Now H1 prefix is added and button is selected
      expect(controller.text, '# Hello world');
      expect(tester.widget<MechanixIconButton>(h1Finder).isSelected, isTrue);

      // Tap H1 button again to untoggle
      await tester.tap(h1Finder);
      await tester.pumpAndSettle();

      // H1 prefix is removed
      expect(controller.text, 'Hello world');
      expect(tester.widget<MechanixIconButton>(h1Finder).isSelected, isFalse);
    });

    testWidgets('switching to Link mode reveals link action buttons', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byKey(const Key('notes_link_code_button')), findsNothing);

      await tester.tap(find.byKey(const Key('notes_link_toggle')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notes_link_code_button')), findsOneWidget);
      expect(
        find.byKey(const Key('notes_link_checklist_button')),
        findsOneWidget,
      );

      // Tapping link code button executes without error
      await tester.tap(find.byKey(const Key('notes_link_code_button')));
      await tester.pumpAndSettle();
    });

    testWidgets('tapping Code block button toggles and unwraps code fence', (
      tester,
    ) async {
      controller.value = const TextEditingValue(
        text: 'print("hello");\n',
        selection: TextSelection.collapsed(offset: 0),
      );
      await tester.pumpWidget(buildTestWidget());

      // Switch to Link mode
      await tester.tap(find.byKey(const Key('notes_link_toggle')));
      await tester.pumpAndSettle();

      final codeBtn = find.byKey(const Key('notes_link_code_button'));
      expect(tester.widget<MechanixIconButton>(codeBtn).isSelected, isFalse);

      // Tap Code button to wrap in code fence
      await tester.tap(codeBtn);
      await tester.pumpAndSettle();
      expect(controller.text, startsWith('```'));
      expect(controller.text, contains('print("hello");'));
      expect(tester.widget<MechanixIconButton>(codeBtn).isSelected, isTrue);

      // Tap Code button again to untoggle / unwrap
      await tester.tap(codeBtn);
      await tester.pumpAndSettle();
      expect(controller.text.trim(), 'print("hello");');
      expect(tester.widget<MechanixIconButton>(codeBtn).isSelected, isFalse);

      // Wrapping selected text in code block and unwrapping it
      controller.value = const TextEditingValue(
        text: 'hello world',
        selection: TextSelection(baseOffset: 0, extentOffset: 11),
      );
      await tester.pumpWidget(buildTestWidget());
      await tester.tap(codeBtn);
      await tester.pumpAndSettle();
      expect(controller.text, '```\nhello world\n```\n');
      expect(tester.widget<MechanixIconButton>(codeBtn).isSelected, isTrue);

      await tester.tap(codeBtn);
      await tester.pumpAndSettle();
      expect(controller.text.trim(), 'hello world');
      expect(tester.widget<MechanixIconButton>(codeBtn).isSelected, isFalse);

      // Scenario 1: Word with no selection (test|) puts test inside code block
      controller.value = const TextEditingValue(
        text: 'test',
        selection: TextSelection.collapsed(offset: 4),
      );
      await tester.pumpWidget(buildTestWidget());
      await tester.tap(codeBtn);
      await tester.pumpAndSettle();
      expect(controller.text, '```\ntest\n```\n');
      expect(controller.selection.baseOffset, 4);
      expect(controller.selection.extentOffset, 8);

      // Untoggle back
      await tester.tap(codeBtn);
      await tester.pumpAndSettle();
      expect(controller.text.trim(), 'test');

      // Scenario 2: Partial selection or cursor inside sentence puts entire sentence inside code block
      controller.value = const TextEditingValue(
        text: 'Hello world from flutter',
        selection: TextSelection(baseOffset: 6, extentOffset: 16), // 'world from'
      );
      await tester.pumpWidget(buildTestWidget());
      await tester.tap(codeBtn);
      await tester.pumpAndSettle();
      expect(controller.text, '```\nHello world from flutter\n```\n');

      // Untoggle back
      await tester.tap(codeBtn);
      await tester.pumpAndSettle();
      expect(controller.text.trim(), 'Hello world from flutter');

      // Multiline selection spanning lines wraps all touched lines
      controller.value = const TextEditingValue(
        text: 'line one\nline two\nline three',
        selection: TextSelection(baseOffset: 5, extentOffset: 17), // 'one\nline two'
      );
      await tester.pumpWidget(buildTestWidget());
      await tester.tap(codeBtn);
      await tester.pumpAndSettle();
      expect(
        controller.text,
        '```\nline one\nline two\n```\nline three',
      );
    });

    testWidgets(
      'tapping Bold button toggles bold syntax and updates button active state',
      (tester) async {
        controller.value = const TextEditingValue(
          text: 'Hello world',
          selection: TextSelection(baseOffset: 0, extentOffset: 5),
        );

        await tester.pumpWidget(buildTestWidget());

        final boldFinder = find.byKey(const Key('notes_text_bold_button'));
        expect(
          tester.widget<MechanixIconButton>(boldFinder).isSelected,
          isFalse,
        );

        // Tap bold button
        await tester.tap(boldFinder);
        await tester.pumpAndSettle();

        // Bold is now applied
        expect(controller.text, '**Hello** world');
        expect(
          tester.widget<MechanixIconButton>(boldFinder).isSelected,
          isTrue,
        );

        // Select the bold formatted word and tap bold again to untoggle
        controller.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 9,
        );
        await tester.pumpAndSettle();

        await tester.tap(boldFinder);
        await tester.pumpAndSettle();

        expect(controller.text, 'Hello world');
        expect(
          tester.widget<MechanixIconButton>(boldFinder).isSelected,
          isFalse,
        );
      },
    );

    testWidgets('tapping Italic and Strikethrough toggles respective syntax', (
      tester,
    ) async {
      controller.value = const TextEditingValue(
        text: 'Testing styles',
        selection: TextSelection(baseOffset: 0, extentOffset: 7),
      );

      await tester.pumpWidget(buildTestWidget());

      final italicFinder = find.byKey(const Key('notes_text_italic_button'));
      final strikeFinder = find.byKey(
        const Key('notes_text_strikethrough_button'),
      );

      // Apply italic
      await tester.tap(italicFinder);
      await tester.pumpAndSettle();
      expect(controller.text, '*Testing* styles');
      expect(
        tester.widget<MechanixIconButton>(italicFinder).isSelected,
        isTrue,
      );

      // Select italic word and untoggle
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 9,
      );
      await tester.pumpAndSettle();
      await tester.tap(italicFinder);
      await tester.pumpAndSettle();
      expect(controller.text, 'Testing styles');

      // Select and apply strikethrough
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 7,
      );
      await tester.pumpAndSettle();
      await tester.tap(strikeFinder);
      await tester.pumpAndSettle();
      expect(controller.text, '~~Testing~~ styles');
      expect(
        tester.widget<MechanixIconButton>(strikeFinder).isSelected,
        isTrue,
      );
    });

    testWidgets(
      'tapping formatting button when selecting text inside delimiters un-formats correctly',
      (tester) async {
        final boldFinder = find.byKey(const Key('notes_text_bold_button'));
        final italicFinder = find.byKey(const Key('notes_text_italic_button'));
        final strikeFinder = find.byKey(
          const Key('notes_text_strikethrough_button'),
        );

        // 1. **ojas** with 'ojas' selected (offsets 2..6) -> taps Bold -> unbolds to 'ojas'
        controller.value = const TextEditingValue(
          text: '**ojas**',
          selection: TextSelection(baseOffset: 2, extentOffset: 6),
        );
        await tester.pumpWidget(buildTestWidget());
        expect(tester.widget<MechanixIconButton>(boldFinder).isSelected, isTrue);
        await tester.tap(boldFinder);
        await tester.pumpAndSettle();
        expect(controller.text, 'ojas');
        expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 4));
        expect(tester.widget<MechanixIconButton>(boldFinder).isSelected, isFalse);

        // 2. *ojas* with 'ojas' selected (offsets 1..5) -> taps Italic -> un-italics to 'ojas'
        controller.value = const TextEditingValue(
          text: '*ojas*',
          selection: TextSelection(baseOffset: 1, extentOffset: 5),
        );
        await tester.pumpWidget(buildTestWidget());
        expect(tester.widget<MechanixIconButton>(italicFinder).isSelected, isTrue);
        await tester.tap(italicFinder);
        await tester.pumpAndSettle();
        expect(controller.text, 'ojas');
        expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 4));
        expect(tester.widget<MechanixIconButton>(italicFinder).isSelected, isFalse);

        // 3. ~~ojas~~ with 'ojas' selected (offsets 2..6) -> taps Strike -> un-strikes to 'ojas'
        controller.value = const TextEditingValue(
          text: '~~ojas~~',
          selection: TextSelection(baseOffset: 2, extentOffset: 6),
        );
        await tester.pumpWidget(buildTestWidget());
        expect(tester.widget<MechanixIconButton>(strikeFinder).isSelected, isTrue);
        await tester.tap(strikeFinder);
        await tester.pumpAndSettle();
        expect(controller.text, 'ojas');
        expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 4));
        expect(tester.widget<MechanixIconButton>(strikeFinder).isSelected, isFalse);

        // 4. **hello world** with 'hello' selected (offsets 2..7) -> taps Bold -> 'hello **world**'
        controller.value = const TextEditingValue(
          text: '**hello world**',
          selection: TextSelection(baseOffset: 2, extentOffset: 7),
        );
        await tester.pumpWidget(buildTestWidget());
        await tester.tap(boldFinder);
        await tester.pumpAndSettle();
        expect(controller.text, 'hello **world**');
        expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 5));

        // 5. **hello world** with 'world' selected (offsets 8..13) -> taps Bold -> '**hello** world'
        controller.value = const TextEditingValue(
          text: '**hello world**',
          selection: TextSelection(baseOffset: 8, extentOffset: 13),
        );
        await tester.pumpWidget(buildTestWidget());
        await tester.tap(boldFinder);
        await tester.pumpAndSettle();
        expect(controller.text, '**hello** world');
        expect(controller.selection, const TextSelection(baseOffset: 10, extentOffset: 15));
      },
    );

    for (final c in const [
      ('notes_text_bold_button', '**'),
      ('notes_text_italic_button', '*'),
      ('notes_text_strikethrough_button', '~~'),
    ]) {
      testWidgets('${c.$1} with no selection toggles active/inactive', (
        tester,
      ) async {
        controller.value = const TextEditingValue(
          text: 'Hi ',
          selection: TextSelection.collapsed(offset: 3),
        );
        await tester.pumpWidget(buildTestWidget());
        final btn = find.byKey(Key(c.$1));
        expect(tester.widget<MechanixIconButton>(btn).isSelected, isFalse);

        // First tap: inserts empty pair and becomes active.
        await tester.tap(btn);
        await tester.pumpAndSettle();
        expect(controller.text, 'Hi ${c.$2}${c.$2}');
        expect(tester.widget<MechanixIconButton>(btn).isSelected, isTrue);

        // Second tap: removes the empty pair and becomes inactive.
        await tester.tap(btn);
        await tester.pumpAndSettle();
        expect(controller.text, 'Hi ');
        expect(controller.selection, const TextSelection.collapsed(offset: 3));
        expect(tester.widget<MechanixIconButton>(btn).isSelected, isFalse);
      });

      testWidgets('${c.$1} inside formatted text steps out of it', (
        tester,
      ) async {
        final text = '${c.$2}abc${c.$2}';
        controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: c.$2.length + 3),
        );
        await tester.pumpWidget(buildTestWidget());
        final btn = find.byKey(Key(c.$1));
        expect(tester.widget<MechanixIconButton>(btn).isSelected, isTrue);

        await tester.tap(btn);
        await tester.pumpAndSettle();
        expect(controller.text, text);
        expect(controller.selection.baseOffset, text.length);
        expect(tester.widget<MechanixIconButton>(btn).isSelected, isFalse);
      });
    }

    group('style state follows the caret (contentStart < caret <= end)', () {
      final boldKey = find.byKey(const Key('notes_text_bold_button'));
      final italicKey = find.byKey(const Key('notes_text_italic_button'));
      final strikeKey = find.byKey(
        const Key('notes_text_strikethrough_button'),
      );

      Future<({bool bold, bool italic, bool strike})> stateAt(
        WidgetTester tester,
        String text,
        TextSelection selection,
      ) async {
        controller.value = TextEditingValue(text: text, selection: selection);
        await tester.pump();
        return (
          bold: tester.widget<MechanixIconButton>(boldKey).isSelected == true,
          italic:
              tester.widget<MechanixIconButton>(italicKey).isSelected == true,
          strike:
              tester.widget<MechanixIconButton>(strikeKey).isSelected == true,
        );
      }

      // (text, first active caret, last active caret, bold, italic, strike)
      const cases = [
        ('***word***', 4, 7, true, true, false),
        ('**word**', 3, 6, true, false, false),
        ('*word*', 2, 5, false, true, false),
        ('~~word~~', 3, 6, false, false, true),
        ('a ***word*** b', 6, 9, true, true, false),
      ];

      for (final c in cases) {
        testWidgets('${c.$1}: active only at ${c.$2}..${c.$3}', (tester) async {
          await tester.pumpWidget(buildTestWidget());
          for (var caret = 0; caret <= c.$1.length; caret++) {
            final on = caret >= c.$2 && caret <= c.$3;
            final s = await stateAt(
              tester,
              c.$1,
              TextSelection.collapsed(offset: caret),
            );
            expect(s.bold, on && c.$4, reason: 'bold at $caret');
            expect(s.italic, on && c.$5, reason: 'italic at $caret');
            expect(s.strike, on && c.$6, reason: 'strike at $caret');
          }
        });
      }

      for (final prefix in const [
        '# ',
        '## ',
        '### ',
        '#### ',
        '##### ',
        '###### ',
        '- ',
        '1. ',
        '- [ ] ',
        '> ',
      ]) {
        testWidgets('"$prefix***word***" follows the same rule', (
          tester,
        ) async {
          await tester.pumpWidget(buildTestWidget());
          final text = '$prefix***word***';
          final p = prefix.length;
          for (var caret = 0; caret <= text.length; caret++) {
            final on = caret >= p + 4 && caret <= p + 7;
            final s = await stateAt(
              tester,
              text,
              TextSelection.collapsed(offset: caret),
            );
            expect(s.bold, on, reason: 'bold at $caret');
            expect(s.italic, on, reason: 'italic at $caret');
          }
        });
      }

      testWidgets('partial overlap: each style follows its own letters', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());
        // **ab *cd* ef**  bold letters 2..12, italic letters 6..8
        const text = '**ab *cd* ef**';
        for (var caret = 0; caret <= text.length; caret++) {
          final s = await stateAt(
            tester,
            text,
            TextSelection.collapsed(offset: caret),
          );
          expect(s.bold, caret >= 3 && caret <= 12, reason: 'bold at $caret');
          expect(
            s.italic,
            caret >= 7 && caret <= 8,
            reason: 'italic at $caret',
          );
        }
      });

      testWidgets('empty pair stays armed: **|**, *|*, ***|***, ~~|~~', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());
        var s = await stateAt(
          tester,
          'x ****',
          const TextSelection.collapsed(offset: 4),
        );
        expect((s.bold, s.italic), (true, false));
        s = await stateAt(
          tester,
          'x **',
          const TextSelection.collapsed(offset: 3),
        );
        expect((s.bold, s.italic), (false, true));
        s = await stateAt(
          tester,
          'x ******',
          const TextSelection.collapsed(offset: 5),
        );
        expect((s.bold, s.italic), (true, true));
        s = await stateAt(
          tester,
          'x ~~~~',
          const TextSelection.collapsed(offset: 4),
        );
        expect(s.strike, isTrue);
      });

      testWidgets('selection: on only when every selected letter has it', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());
        const text = 'a ***word*** b';
        // Just the word.
        var s = await stateAt(
          tester,
          text,
          const TextSelection(baseOffset: 5, extentOffset: 9),
        );
        expect((s.bold, s.italic), (true, true));
        // Word with its markers: markers are ignored.
        s = await stateAt(
          tester,
          text,
          const TextSelection(baseOffset: 2, extentOffset: 12),
        );
        expect((s.bold, s.italic), (true, true));
        // Includes the plain `a`.
        s = await stateAt(
          tester,
          text,
          const TextSelection(baseOffset: 0, extentOffset: 12),
        );
        expect((s.bold, s.italic), (false, false));
        // Only markers selected: no letters, nothing on.
        s = await stateAt(
          tester,
          text,
          const TextSelection(baseOffset: 2, extentOffset: 5),
        );
        expect((s.bold, s.italic), (false, false));
      });
    });

    testWidgets('***bold** more* keeps italic-only area before bold', (
      tester,
    ) async {
      const text = '***bold** more*';
      controller.value = const TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: 12),
      );
      await tester.pumpWidget(buildTestWidget());
      final bold = find.byKey(const Key('notes_text_bold_button'));
      final italic = find.byKey(const Key('notes_text_italic_button'));
      expect(tester.widget<MechanixIconButton>(bold).isSelected, isFalse);
      expect(tester.widget<MechanixIconButton>(italic).isSelected, isTrue);
    });

    testWidgets('tapping Checklist button toggles checklist format', (
      tester,
    ) async {
      controller.value = const TextEditingValue(
        text: 'Buy groceries',
        selection: TextSelection.collapsed(offset: 4),
      );

      await tester.pumpWidget(buildTestWidget());

      // Switch to Link mode where checklist button is located
      await tester.tap(find.byKey(const Key('notes_link_toggle')));
      await tester.pumpAndSettle();

      final checklistFinder = find.byKey(
        const Key('notes_link_checklist_button'),
      );
      expect(
        tester.widget<MechanixIconButton>(checklistFinder).isSelected,
        isFalse,
      );

      // Tap checklist
      await tester.tap(checklistFinder);
      await tester.pumpAndSettle();

      expect(controller.text, '- [ ] Buy groceries');
      expect(
        tester.widget<MechanixIconButton>(checklistFinder).isSelected,
        isTrue,
      );

      // Tap checklist again to untoggle
      await tester.tap(checklistFinder);
      await tester.pumpAndSettle();

      expect(controller.text, 'Buy groceries');
      expect(
        tester.widget<MechanixIconButton>(checklistFinder).isSelected,
        isFalse,
      );
    });

    testWidgets(
      'newly created empty note with # has H1 active and Body inactive in EditorBottomBar',
      (tester) async {
        controller.value = const TextEditingValue(
          text: '# ',
          selection: TextSelection.collapsed(offset: 2),
        );

        await tester.pumpWidget(buildTestWidget());

        final h1Finder = find.byKey(const Key('notes_text_contextual_button'));
        final bodyFinder = find.byKey(const Key('notes_text_body_button'));

        expect(tester.widget<MechanixIconButton>(h1Finder).isSelected, isTrue);
        expect(
          tester.widget<MechanixIconButton>(bodyFinder).isSelected,
          isFalse,
        );
      },
    );

    testWidgets(
      'typing note title on H1 and pressing enter on second line has Body active',
      (tester) async {
        controller.value = const TextEditingValue(
          text: '# My Note Title\n',
          selection: TextSelection.collapsed(offset: 16),
        );

        await tester.pumpWidget(buildTestWidget());

        final h1Finder = find.byKey(const Key('notes_text_contextual_button'));
        final bodyFinder = find.byKey(const Key('notes_text_body_button'));

        // On line 2 (offset 16), H1 is inactive and body is active
        expect(tester.widget<MechanixIconButton>(h1Finder).isSelected, isFalse);
        expect(
          tester.widget<MechanixIconButton>(bodyFinder).isSelected,
          isTrue,
        );
      },
    );

    testWidgets('H2 line has H2 active and Body inactive', (tester) async {
      controller.value = const TextEditingValue(
        text: '## Subheading',
        selection: TextSelection.collapsed(offset: 5),
      );

      await tester.pumpWidget(buildTestWidget());

      final h1Finder = find.byKey(const Key('notes_text_contextual_button'));
      final h2Finder = find.byKey(const Key('notes_text_h2_button'));
      final bodyFinder = find.byKey(const Key('notes_text_body_button'));

      expect(tester.widget<MechanixIconButton>(h1Finder).isSelected, isFalse);
      expect(tester.widget<MechanixIconButton>(h2Finder).isSelected, isTrue);
      expect(tester.widget<MechanixIconButton>(bodyFinder).isSelected, isFalse);
    });

    testWidgets('H3 through H6 lines map to H2 active and Body inactive', (
      tester,
    ) async {
      for (final prefix in const [
        '### ',
        '#### ',
        '##### ',
        '###### ',
      ]) {
        controller.value = TextEditingValue(
          text: '${prefix}Title',
          selection: TextSelection.collapsed(offset: prefix.length + 2),
        );

        await tester.pumpWidget(buildTestWidget());

        final h1Finder = find.byKey(const Key('notes_text_contextual_button'));
        final h2Finder = find.byKey(const Key('notes_text_h2_button'));
        final bodyFinder = find.byKey(const Key('notes_text_body_button'));

        expect(
          tester.widget<MechanixIconButton>(h1Finder).isSelected,
          isFalse,
          reason: 'H1 at $prefix',
        );
        expect(
          tester.widget<MechanixIconButton>(h2Finder).isSelected,
          isTrue,
          reason: 'H2 at $prefix',
        );
        expect(
          tester.widget<MechanixIconButton>(bodyFinder).isSelected,
          isFalse,
          reason: 'Body at $prefix',
        );
      }
    });
  });
}
