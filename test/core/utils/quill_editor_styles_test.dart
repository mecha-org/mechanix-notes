import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/utils/quill_editor_styles.dart';
import 'package:widgets/widgets.dart';

void main() {
  group('quillEditorStyle and NotesQuillCheckboxBuilder Tests', () {
    testWidgets('builds custom checklist checkbox and handles tap', (
      WidgetTester tester,
    ) async {
      bool? tappedValue;

      await tester.pumpWidget(
        MaterialApp(
          theme: MechanixTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final styles = quillEditorStyle(context);
                final checkboxBuilder = styles.lists?.checkboxUIBuilder;
                expect(checkboxBuilder, isNotNull);

                return checkboxBuilder!.build(
                  context: context,
                  isChecked: false,
                  onChanged: (val) {
                    tappedValue = val;
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(FocusPreserveButton), findsOneWidget);
      expect(find.byType(InkWell), findsOneWidget);
      expect(find.byType(MechanixCheckbox), findsOneWidget);

      final sizedBoxFinder = find.ancestor(
        of: find.byType(MechanixCheckbox),
        matching: find.byType(SizedBox),
      );
      final sizedBox = tester.widget<SizedBox>(sizedBoxFinder.first);
      expect(sizedBox.width, 18);
      expect(sizedBox.height, 18);

      final checkbox = tester.widget<MechanixCheckbox>(
        find.byType(MechanixCheckbox),
      );
      expect(checkbox.value, isFalse);
      expect(
        checkbox.shape,
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      );
      expect(checkbox.checkColor, MechanixTheme.dark.colorScheme.onPrimary);
      expect(
        (checkbox.side as WidgetStateBorderSide?)?.resolve({}),
        BorderSide(
          color: MechanixTheme.dark.colorScheme.onSurfaceVariant,
          width: 2,
        ),
      );
      expect(
        checkbox.fillColor?.resolve({WidgetState.selected}),
        MechanixTheme.dark.colorScheme.primary,
      );

      // Tap the checkbox / InkWell
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      expect(tappedValue, isTrue);
    });

    testWidgets('renders checked state correctly', (
      WidgetTester tester,
    ) async {
      bool? tappedValue;

      await tester.pumpWidget(
        MaterialApp(
          theme: MechanixTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final styles = quillEditorStyle(context);
                final checkboxBuilder = styles.lists?.checkboxUIBuilder;

                return checkboxBuilder!.build(
                  context: context,
                  isChecked: true,
                  onChanged: (val) {
                    tappedValue = val;
                  },
                );
              },
            ),
          ),
        ),
      );

      final checkbox = tester.widget<MechanixCheckbox>(
        find.byType(MechanixCheckbox),
      );
      expect(checkbox.value, isTrue);

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      expect(tappedValue, isFalse);
    });

    testWidgets(
      'lists style has matching verticalSpacing and lineSpacing for checklist uniformity',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: MechanixTheme.dark,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final styles = quillEditorStyle(context);
                  expect(styles.lists?.verticalSpacing.top, 16);
                  expect(styles.lists?.verticalSpacing.bottom, 16);
                  expect(styles.lists?.lineSpacing.top, 16);
                  expect(styles.lists?.lineSpacing.bottom, 16);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
      },
    );

    testWidgets(
      'checklist items have uniform vertical spacing across checked and unchecked states',
      (WidgetTester tester) async {
        final doc = Document.fromJson([
          {
            'insert': 'Item 1\n',
            'attributes': {'list': 'checked'},
          },
          {
            'insert': 'Item 2\n',
            'attributes': {'list': 'unchecked'},
          },
          {
            'insert': 'Item 3\n',
            'attributes': {'list': 'unchecked'},
          },
          {
            'insert': 'Item 4\n',
            'attributes': {'list': 'checked'},
          },
        ]);
        final controller = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: MechanixTheme.dark,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return QuillEditor(
                    controller: controller,
                    focusNode: FocusNode(),
                    scrollController: ScrollController(),
                    config: QuillEditorConfig(
                      customStyles: quillEditorStyle(context),
                      scrollable: false,
                      autoFocus: false,
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final checkboxes = tester
            .widgetList<MechanixCheckbox>(find.byType(MechanixCheckbox))
            .toList();
        expect(checkboxes.length, 4);

        final y0 = tester.getTopLeft(find.byWidget(checkboxes[0])).dy;
        final y1 = tester.getTopLeft(find.byWidget(checkboxes[1])).dy;
        final y2 = tester.getTopLeft(find.byWidget(checkboxes[2])).dy;
        final y3 = tester.getTopLeft(find.byWidget(checkboxes[3])).dy;

        final gap01 = y1 - y0;
        final gap12 = y2 - y1;
        final gap23 = y3 - y2;

        expect((gap01 - gap12).abs(), lessThan(1.0));
        expect((gap12 - gap23).abs(), lessThan(1.0));
      },
    );
  });
}
