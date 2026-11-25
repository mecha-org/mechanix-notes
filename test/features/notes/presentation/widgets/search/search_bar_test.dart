import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/search/search_bar.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';
import 'package:widgets/widgets.dart';

void main() {
  group('SearchAppBar Localization Tests', () {
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

    Widget buildTestWidget({
      bool isSearchActive = false,
      Widget? title,
      String? searchHint,
    }) {
      return MaterialApp(
        theme: MechanixTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: SearchAppBar(
            isSearchActive: isSearchActive,
            controller: controller,
            focusNode: focusNode,
            title: title,
            searchHint: searchHint,
          ),
          body: const SizedBox(),
        ),
      );
    }

    testWidgets('renders localized NOTES title when collapsed', (tester) async {
      await tester.pumpWidget(buildTestWidget(isSearchActive: false));
      await tester.pumpAndSettle();

      expect(find.text('NOTES'), findsOneWidget);
    });

    testWidgets('renders localized SEARCH NOTE hint in active search mode', (tester) async {
      await tester.pumpWidget(buildTestWidget(isSearchActive: true));
      await tester.pumpAndSettle();

      expect(find.text('SEARCH NOTE'), findsOneWidget);
    });
  });

  group('SearchAppBar context menu', () {
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

    /// Shows the search field's menu with [text] and [selection] in it.
    Future<void> showMenu(
      WidgetTester tester,
      String text,
      TextSelection selection,
    ) async {
      controller.value = TextEditingValue(text: text, selection: selection);
      await tester.pumpWidget(
        MaterialApp(
          theme: MechanixTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: SearchAppBar(
              isSearchActive: true,
              controller: controller,
              focusNode: focusNode,
            ),
            body: const SizedBox(),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();
      // What a right-click or long-press does once it has set the selection.
      tester
          .state<EditableTextState>(find.byType(EditableText))
          .toggleToolbar(false);
      await tester.pumpAndSettle();
    }

    testWidgets('an empty field only offers Paste', (tester) async {
      await showMenu(tester, '', const TextSelection.collapsed(offset: 0));

      expect(find.text('Paste'), findsOneWidget);
      expect(find.text('Select all'), findsNothing);
      expect(find.text('Cut'), findsNothing);
      expect(find.text('Copy'), findsNothing);
    });

    testWidgets('text without a selection offers Paste and Select all', (
      tester,
    ) async {
      await showMenu(tester, 'apples', const TextSelection.collapsed(offset: 6));

      expect(find.text('Paste'), findsOneWidget);
      expect(find.text('Select all'), findsOneWidget);
      expect(find.text('Cut'), findsNothing);
      expect(find.text('Copy'), findsNothing);

      await tester.tap(find.text('Select all'));
      await tester.pump();
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 6),
      );
    });

    testWidgets('a selection adds Cut and Copy', (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
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

      await showMenu(
        tester,
        'red apples',
        const TextSelection(baseOffset: 4, extentOffset: 10),
      );

      expect(find.text('Cut'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);

      await tester.tap(find.text('Cut'));
      await tester.pump();
      expect(clipboard, 'apples');
      expect(controller.text, 'red ');
    });
  });
}
