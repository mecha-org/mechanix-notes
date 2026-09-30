import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' hide EditorState;
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/features/notes/bloc/editor/editor_bloc.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_content.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/quill_controller_provider.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/quill_editor_checkbox.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:widgets/widgets.dart';

class MockEditorBloc extends Mock implements EditorBloc {}

void main() {
  group('QuillEditorCheckbox Unit & Integration Tests', () {
    late MockEditorBloc mockEditorBloc;

    setUp(() {
      mockEditorBloc = MockEditorBloc();
      when(() => mockEditorBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => mockEditorBloc.state).thenReturn(
        const EditorInitial(),
      );
    });

    testWidgets('renders unchecked checkbox and toggles with strikethrough', (
      WidgetTester tester,
    ) async {
      final doc = Document.fromJson([
        {
          'insert': 'Task 1\n',
          'attributes': {'list': 'unchecked'},
        },
      ]);
      final controller = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: MechanixTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<EditorBloc>.value(
            value: mockEditorBloc,
            child: QuillControllerProvider(
              controller: controller,
              focusNode: focusNode,
              child: const Scaffold(
                body: Column(
                  children: [
                    Expanded(child: EditorContent()),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Checkbox is rendered
      expect(find.byType(QuillEditorCheckbox), findsOneWidget);
      expect(find.byType(MechanixCheckbox), findsOneWidget);

      final checkbox = tester.widget<MechanixCheckbox>(
        find.byType(MechanixCheckbox),
      );
      expect(checkbox.value, isFalse);

      // Verify line text does not have strikethrough initially
      final blockNode = doc.root.children.first as Block;
      final lineNode = blockNode.children.first as Line;
      expect(lineNode.style.containsKey(Attribute.strikeThrough.key), isFalse);

      // Tap checkbox to check it
      await tester.tap(find.byType(InkResponse));
      await tester.pumpAndSettle();

      // Verify strikethrough is applied to the text
      final firstLeaf = lineNode.children.first as Leaf;
      expect(
        firstLeaf.style.attributes[Attribute.strikeThrough.key]?.value,
        Attribute.strikeThrough.value,
      );

      // Tap checkbox again to uncheck it
      await tester.tap(find.byType(InkResponse));
      await tester.pumpAndSettle();

      // Verify strikethrough is removed
      final updatedLeaf = lineNode.children.first as Leaf;
      expect(
        updatedLeaf.style.containsKey(Attribute.strikeThrough.key),
        isFalse,
      );
    });

    testWidgets('empty checklist line handles tap without error', (
      WidgetTester tester,
    ) async {
      final doc = Document.fromJson([
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked'},
        },
      ]);
      final controller = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: MechanixTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<EditorBloc>.value(
            value: mockEditorBloc,
            child: QuillControllerProvider(
              controller: controller,
              focusNode: focusNode,
              child: const Scaffold(
                body: Column(
                  children: [
                    Expanded(child: EditorContent()),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QuillEditorCheckbox), findsOneWidget);

      // Tap without crashing
      await tester.tap(find.byType(InkResponse));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'displays pressed color halo larger than checkbox when pressing',
      (WidgetTester tester) async {
        final doc = Document.fromJson([
          {
            'insert': 'Task with pressed halo\n',
            'attributes': {'list': 'unchecked'},
          },
        ]);
        final controller = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
        final focusNode = FocusNode();

        await tester.pumpWidget(
          MaterialApp(
            theme: MechanixTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<EditorBloc>.value(
              value: mockEditorBloc,
              child: QuillControllerProvider(
                controller: controller,
                focusNode: focusNode,
                child: const Scaffold(
                  body: Column(
                    children: [
                      Expanded(child: EditorContent()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final checkboxFinder = find.byType(MechanixCheckbox);
        expect(checkboxFinder, findsOneWidget);

        // Positioned halo container is present and larger than the 18x18 checkbox
        final positionedFinder = find.descendant(
          of: find.byType(QuillEditorCheckbox),
          matching: find.byType(Positioned),
        );
        expect(positionedFinder, findsOneWidget);
        final positioned = tester.widget<Positioned>(positionedFinder);
        expect(positioned.left, -8);
        expect(positioned.right, -8);
        expect(positioned.top, -8);
        expect(positioned.bottom, -8);

        // Start gesture (press and hold down)
        final gesture = await tester.startGesture(
          tester.getCenter(checkboxFinder),
        );
        await tester.pump(kPressTimeout);

        // While pressed, Container has pressed color with opacity
        final containerFinder = find.descendant(
          of: positionedFinder,
          matching: find.byType(Container),
        );
        final container = tester.widget<Container>(
          containerFinder,
        );
        final decoration = container.decoration as BoxDecoration?;
        expect(decoration?.shape, BoxShape.circle);
        expect(decoration?.color, isNotNull);
        expect(decoration?.color?.a, greaterThan(0.0));

        // Release gesture
        await gesture.up();
        await tester.pumpAndSettle();
      },
    );
  });
}
