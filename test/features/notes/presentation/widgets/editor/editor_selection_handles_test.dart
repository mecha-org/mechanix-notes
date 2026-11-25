import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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

/// The editor's touch selection handles follow Android: Material teardrops
/// whose points touch the ends of the selection.
void main() {
  late MockEditorBloc editorBloc;
  late MarkdownEditorController controller;
  late FocusNode focusNode;

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
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  testWidgets(
    'touch double tap shows Android handles pointing at the selection ends',
    (tester) async {
      controller = MarkdownEditorController(text: 'alpha bravo charlie');
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
      // Unmount at the end so the 2s autosave timer is cancelled.
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pump();

      final render = tester
          .state<MarkdownEditableTextState>(find.byType(MarkdownEditableText))
          .renderEditable!;
      Offset caretAt(int offset) => render.localToGlobal(
        render.getLocalRectForCaret(TextPosition(offset: offset)).center,
      );
      Rect drawnHandle(String kind) => tester.getRect(
        find.descendant(
          of: find.byKey(ValueKey('markdown-selection-handle-$kind')),
          matching: find.byType(CustomPaint),
        ),
      );

      final target = caretAt(8);
      await tester.tapAt(target, kind: PointerDeviceKind.touch);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(target, kind: PointerDeviceKind.touch);
      await tester.pump();
      expect(controller.selection.textInside(controller.text), 'bravo');

      final start = drawnHandle('start');
      final end = drawnHandle('end');
      expect(start.size, const Size(22, 22));
      expect(end.size, const Size(22, 22));
      // Android hangs the start handle left of the text and the end handle
      // right of it, each with its point on the selection edge.
      expect(start.right, moreOrLessEquals(caretAt(6).dx, epsilon: 1.5));
      expect(end.left, moreOrLessEquals(caretAt(11).dx, epsilon: 1.5));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'dragging the end handle extends the selection',
    (tester) async {
      controller = MarkdownEditorController(text: 'alpha bravo charlie');
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
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pump();

      final render = tester
          .state<MarkdownEditableTextState>(find.byType(MarkdownEditableText))
          .renderEditable!;
      Offset caretAt(int offset) => render.localToGlobal(
        render.getLocalRectForCaret(TextPosition(offset: offset)).center,
      );

      final target = caretAt(8);
      await tester.tapAt(target, kind: PointerDeviceKind.touch);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(target, kind: PointerDeviceKind.touch);
      await tester.pump();
      expect(controller.selection.textInside(controller.text), 'bravo');

      final handle = tester.getCenter(
        find.byKey(const ValueKey('markdown-selection-handle-end')),
      );
      final gesture = await tester.startGesture(
        handle,
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();
      // Past the touch slop first, then on to the end of "charlie".
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveTo(Offset(caretAt(19).dx + 4, handle.dy));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(controller.selection.textInside(controller.text), 'bravo charlie');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
