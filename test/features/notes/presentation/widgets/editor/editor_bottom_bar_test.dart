import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/bottom_bar/notes_text_link_control.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_bottom_bar.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/quill_controller_provider.dart';
import 'package:widgets/widgets.dart';

void main() {
  late QuillController controller;
  late FocusNode focusNode;

  setUp(() {
    controller = QuillController.basic();
    focusNode = FocusNode();
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: QuillControllerProvider(
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

    testWidgets(
      'tapping H1 button toggles Header 1 attribute on Quill selection',
      (tester) async {
        controller.document.insert(0, 'Hello world');
        controller.updateSelection(
          const TextSelection(baseOffset: 0, extentOffset: 5),
          ChangeSource.local,
        );

        await tester.pumpWidget(buildTestWidget());

        // Initially not H1
        expect(
          controller.getSelectionStyle().attributes[Attribute.h1.key],
          isNull,
        );

        // Tap H1 contextual button
        await tester.tap(find.byKey(const Key('notes_text_contextual_button')));
        await tester.pumpAndSettle();

        // Now H1 is applied
        expect(
          controller.getSelectionStyle().attributes[Attribute.h1.key]?.value,
          1,
        );

        // Tap H1 contextual button again to untoggle
        await tester.tap(find.byKey(const Key('notes_text_contextual_button')));
        await tester.pumpAndSettle();

        // H1 is removed
        expect(
          controller.getSelectionStyle().attributes[Attribute.h1.key],
          isNull,
        );
      },
    );

    testWidgets('switching to Link mode reveals link image button', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(
        find.byKey(const Key('notes_link_image_button')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('notes_link_toggle')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('notes_link_image_button')),
        findsOneWidget,
      );

      // Tapping link image button executes without error
      await tester.tap(find.byKey(const Key('notes_link_image_button')));
      await tester.pumpAndSettle();
    });

    testWidgets('tapping Bold button toggles bold attribute and updates button active state', (
      tester,
    ) async {
      controller.document.insert(0, 'Hello world');
      controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
        ChangeSource.local,
      );

      await tester.pumpWidget(buildTestWidget());

      // Bold is initially not active
      final boldFinder = find.byKey(const Key('notes_text_bold_button'));
      expect(tester.widget<MechanixIconButton>(boldFinder).isSelected, isFalse);
      expect(controller.getSelectionStyle().attributes[Attribute.bold.key], isNull);

      // Tap bold button
      await tester.tap(boldFinder);
      await tester.pumpAndSettle();

      // Bold is now applied and button is selected
      expect(controller.getSelectionStyle().attributes[Attribute.bold.key]?.value, true);
      expect(tester.widget<MechanixIconButton>(boldFinder).isSelected, isTrue);

      // Tap bold again to untoggle
      await tester.tap(boldFinder);
      await tester.pumpAndSettle();

      expect(controller.getSelectionStyle().attributes[Attribute.bold.key], isNull);
      expect(tester.widget<MechanixIconButton>(boldFinder).isSelected, isFalse);
    });

    testWidgets('tapping Italic, Underline, and Strikethrough toggles respective attributes', (
      tester,
    ) async {
      controller.document.insert(0, 'Testing styles');
      controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 7),
        ChangeSource.local,
      );

      await tester.pumpWidget(buildTestWidget());

      final italicFinder = find.byKey(const Key('notes_text_italic_button'));
      final underlineFinder = find.byKey(const Key('notes_text_underline_button'));
      final strikeFinder = find.byKey(const Key('notes_text_strikethrough_button'));

      // Apply italic
      await tester.tap(italicFinder);
      await tester.pumpAndSettle();
      expect(controller.getSelectionStyle().attributes[Attribute.italic.key]?.value, true);
      expect(tester.widget<MechanixIconButton>(italicFinder).isSelected, isTrue);

      // Apply underline
      await tester.tap(underlineFinder);
      await tester.pumpAndSettle();
      expect(controller.getSelectionStyle().attributes[Attribute.underline.key]?.value, true);
      expect(tester.widget<MechanixIconButton>(underlineFinder).isSelected, isTrue);

      // Apply strikethrough
      await tester.tap(strikeFinder);
      await tester.pumpAndSettle();
      expect(controller.getSelectionStyle().attributes[Attribute.strikeThrough.key]?.value, true);
      expect(tester.widget<MechanixIconButton>(strikeFinder).isSelected, isTrue);
    });

    testWidgets('tapping Checklist button toggles checklist format', (
      tester,
    ) async {
      controller.document.insert(0, 'Buy groceries\n');
      controller.updateSelection(
        const TextSelection.collapsed(offset: 4),
        ChangeSource.local,
      );

      await tester.pumpWidget(buildTestWidget());

      // Switch to Link mode where checklist button is located
      await tester.tap(find.byKey(const Key('notes_link_toggle')));
      await tester.pumpAndSettle();

      final checklistFinder = find.byKey(const Key('notes_link_checklist_button'));
      expect(tester.widget<MechanixIconButton>(checklistFinder).isSelected, isFalse);

      // Tap checklist
      await tester.tap(checklistFinder);
      await tester.pumpAndSettle();

      expect(
        controller.getSelectionStyle().attributes[Attribute.list.key]?.value,
        Attribute.unchecked.value,
      );
      expect(tester.widget<MechanixIconButton>(checklistFinder).isSelected, isTrue);

      // Tap checklist again to untoggle
      await tester.tap(checklistFinder);
      await tester.pumpAndSettle();

      expect(controller.getSelectionStyle().attributes[Attribute.list.key], isNull);
      expect(tester.widget<MechanixIconButton>(checklistFinder).isSelected, isFalse);
    });

    testWidgets(
      'newly created empty note has H1 active and Body inactive in EditorBottomBar',
      (tester) async {
        controller.dispose();
        controller = QuillController(
          document: Document.fromJson([
            {
              'insert': '\n',
              'attributes': {'header': 1},
            },
          ]),
          selection: const TextSelection.collapsed(offset: 0),
        );

        await tester.pumpWidget(buildTestWidget());

        final h1Finder = find.byKey(const Key('notes_text_contextual_button'));
        final bodyFinder = find.byKey(const Key('notes_text_body_button'));

        expect(tester.widget<MechanixIconButton>(h1Finder).isSelected, isTrue);
        expect(tester.widget<MechanixIconButton>(bodyFinder).isSelected, isFalse);
      },
    );

    testWidgets(
      'typing note title and pressing enter switches next block to normal body text',
      (tester) async {
        controller.dispose();
        controller = QuillController(
          document: Document.fromJson([
            {
              'insert': '\n',
              'attributes': {'header': 1},
            },
          ]),
          selection: const TextSelection.collapsed(offset: 0),
        );

        await tester.pumpWidget(buildTestWidget());

        final h1Finder = find.byKey(const Key('notes_text_contextual_button'));
        final bodyFinder = find.byKey(const Key('notes_text_body_button'));

        // Initially H1 is active
        expect(tester.widget<MechanixIconButton>(h1Finder).isSelected, isTrue);
        expect(tester.widget<MechanixIconButton>(bodyFinder).isSelected, isFalse);

        // Type "My Note Title"
        controller.replaceText(0, 0, 'My Note Title', null);
        controller.updateSelection(
          const TextSelection.collapsed(offset: 13),
          ChangeSource.local,
        );
        await tester.pumpAndSettle();

        expect(tester.widget<MechanixIconButton>(h1Finder).isSelected, isTrue);
        expect(tester.widget<MechanixIconButton>(bodyFinder).isSelected, isFalse);

        // Press Enter at the end of the title line
        controller.replaceText(13, 0, '\n', null);
        controller.updateSelection(
          const TextSelection.collapsed(offset: 14),
          ChangeSource.local,
        );
        await tester.pumpAndSettle();

        // The new line (next block) should automatically switch to body text
        expect(tester.widget<MechanixIconButton>(h1Finder).isSelected, isFalse);
        expect(tester.widget<MechanixIconButton>(bodyFinder).isSelected, isTrue);

        // Verify document structure: line 1 has H1, line 2 has no header
        final delta = controller.document.toDelta().toJson();
        expect(delta, [
          {'insert': 'My Note Title'},
          {
            'insert': '\n',
            'attributes': {'header': 1},
          },
          {'insert': '\n'},
        ]);
      },
    );
  });
}
