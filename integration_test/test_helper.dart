import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart';
import 'package:mechanix_notes/core/utils/app_paths.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository_impl.dart';
import 'package:mechanix_notes/main.dart' as app;

// ---------------------------------------------------------------
// Setup
// ---------------------------------------------------------------

/// Call once at the top of `main()` in every integration test file.
///
/// All app data (database, search index, note files) goes to a temp folder
/// for this file, so the user's real notes are never touched. The search
/// index can only be opened once per process, so the folder is shared by
/// every test in the file and [appTest] empties it before each test.
void setUpIntegrationTests() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dataRoot;
  setUpAll(() {
    dataRoot = Directory.systemTemp.createTempSync('mechanix_notes_it_');
    AppPaths.dataRootOverride = dataRoot.path;
  });
  tearDownAll(() {
    AppPaths.dataRootOverride = null;
    if (dataRoot.existsSync()) dataRoot.deleteSync(recursive: true);
  });
}

/// A test that starts the app with no notes and waits for the home screen.
void appTest(
  String description,
  Future<void> Function(WidgetTester tester) body, {
  Timeout? timeout,
}) {
  testWidgets(description, timeout: timeout, (tester) async {
    await deleteAllNotes();

    // The editor calls a menu plugin that does not exist on eLinux
    // (MissingPluginException ... dismissMenu). Answer it with "done".
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('native_adaptive_toolbox/menu'),
      (MethodCall call) async {
        if (call.method == 'dismissMenu') return null;
        throw MissingPluginException('Not faked in test: ${call.method}');
      },
    );

    // A Num Lock keyboard message from this device can fail a test.
    // Ignore ONLY that one message. Everything else is reported normally.
    final originalHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final text = details.exceptionAsString();
      if (text.contains('RawKeyboard reported')) {
        debugPrint('IGNORED KNOWN NOISE: ${text.split('\n').first}');
        return;
      }
      originalHandler?.call(details);
    };

    try {
      app.main(const <String>[]);
      await waitForHome(tester);
      await body(tester);
    } finally {
      // Remove the app (closes its database) while the handler above is
      // still on, then restore the normal error handler.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
      FlutterError.onError = originalHandler;
    }
  });
}

// ---------------------------------------------------------------
// Direct data access (to check what was really saved)
// ---------------------------------------------------------------

/// Notes currently saved in the database, newest first.
/// Shares the app's open database, so it must not close the repository.
Future<List<NoteMetaData>> savedNotes() =>
    NoteRepositoryImpl().watchNotes().first;

Future<NoteModel?> savedNote(String id) => NoteRepositoryImpl().getNoteById(id);

Future<void> deleteAllNotes() async {
  final notes = await savedNotes();
  if (notes.isNotEmpty) {
    await NoteRepositoryImpl().deleteNotes(notes.map((n) => n.id).toList());
  }
}

// ---------------------------------------------------------------
// Finders
// ---------------------------------------------------------------

/// An image (also inside an [ImageIcon]) showing [asset].
Finder imageAsset(String asset) => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName == asset,
);

Finder get addButton => find.byIcon(Icons.add);
Finder get editor => find.byType(LiveMarkdownEditor);
Finder get searchField => find.byType(TextField);

/// Search results are rich text with the match highlighted.
Finder searchResult(String text) =>
    find.textContaining(text, findRichText: true);

Finder noteTile(String id) => find.byKey(ValueKey('note_tile_$id'));

// ---------------------------------------------------------------
// Waiting
// ---------------------------------------------------------------

/// Waits (up to [timeout]) until [finder] shows something. No fixed sleeping.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      throw TestFailure('Timed out after $timeout waiting for: $finder');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Waits (up to [timeout]) until [finder] shows nothing any more.
Future<void> waitUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(end)) {
      throw TestFailure(
        'Timed out after $timeout waiting to disappear: $finder',
      );
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Waits until the home screen is up, loaded and takes taps.
Future<void> waitForHome(WidgetTester tester) async {
  await waitFor(tester, find.text('NOTES'));
  await waitUntilGone(tester, find.byType(CircularProgressIndicator));
  await waitFor(tester, addButton.hitTestable());
  await tester.pump(const Duration(milliseconds: 300));
}

/// Waits until the editor is open and takes taps.
Future<void> waitForEditor(WidgetTester tester) async {
  await waitFor(tester, editor.hitTestable());
  await tester.pump(const Duration(milliseconds: 500));
}

// ---------------------------------------------------------------
// Editor
// ---------------------------------------------------------------

Future<void> openNewNote(WidgetTester tester) async {
  await tester.tap(addButton);
  await waitForEditor(tester);
}

/// Replaces the whole editor text. The first line becomes the note title.
Future<void> typeInEditor(WidgetTester tester, String text) async {
  await tester.tap(editor);
  await tester.pump(const Duration(milliseconds: 300));
  tester.testTextInput.enterText(text);
  await tester.pump(const Duration(milliseconds: 300));
}

MarkdownEditorController editorController(WidgetTester tester) =>
    tester.widget<LiveMarkdownEditor>(editor).controller;

String editorText(WidgetTester tester) => editorController(tester).text;

/// The app's back button: saves the note and returns to the list.
Future<void> tapEditorBack(WidgetTester tester) async {
  await tester.tap(imageAsset(NotesIcon.backIcon));
  await waitForHome(tester);
}

/// Creates a note from home and returns to home.
Future<void> createNote(WidgetTester tester, String text) async {
  await openNewNote(tester);
  await typeInEditor(tester, text);
  await tapEditorBack(tester);
}

/// Opens the note shown as [title] in the home list.
Future<void> openNote(WidgetTester tester, String title) async {
  await tester.tap(find.text(title).first);
  await waitForEditor(tester);
}

/// Opens the editor's "more" menu.
Future<void> openEditorMenu(WidgetTester tester) async {
  await tester.tap(imageAsset(NotesIcon.moreVertIcon));
  await tester.pump(const Duration(milliseconds: 500));
}

// ---------------------------------------------------------------
// Delete confirmation sheet
// ---------------------------------------------------------------

Future<void> confirmDelete(WidgetTester tester) async {
  await waitFor(tester, find.text('DELETE').hitTestable());
  await tester.tap(find.text('DELETE'));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> cancelDelete(WidgetTester tester) async {
  await waitFor(tester, find.text('CANCEL').hitTestable());
  await tester.tap(find.text('CANCEL'));
  await tester.pump(const Duration(milliseconds: 500));
}

/// Swipes a home list tile left to show its pin/delete actions.
Future<void> swipeNoteTile(WidgetTester tester, String id) async {
  await tester.drag(noteTile(id), const Offset(-300, 0));
  await tester.pump(const Duration(milliseconds: 600));
}

// ---------------------------------------------------------------
// Search
// ---------------------------------------------------------------

Future<void> openSearch(WidgetTester tester) async {
  await tester.tap(imageAsset(NotesIcon.searchIcon).first);
  await waitFor(tester, searchField.hitTestable());
  await tester.pump(const Duration(milliseconds: 300));
}

/// Types [query] and waits for the debounce and the search to finish.
Future<void> searchFor(WidgetTester tester, String query) async {
  await tester.enterText(searchField, query);
  await tester.pump(const Duration(milliseconds: 600));
  await waitUntilGone(tester, find.byType(CircularProgressIndicator));
  await tester.pump(const Duration(milliseconds: 300));
}

/// The search bar's X: clears the query, or closes search when empty.
Future<void> tapSearchClose(WidgetTester tester) async {
  await tester.tap(imageAsset(NotesIcon.closeIcon));
  await tester.pump(const Duration(milliseconds: 600));
}
