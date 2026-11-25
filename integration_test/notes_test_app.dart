import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository_impl.dart';
import 'package:mechanix_notes/features/notes/data/services/note_file_storage.dart';
import 'package:mechanix_notes/features/notes/data/services/notes_watcher.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/markdown_controller_provider.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_note_card.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/search/search_list_view.dart';
import 'package:mechanix_notes/main.dart';
import 'package:widgets/widgets.dart';

/// A note file written to the notes folder before the app starts.
class SeedNote {
  const SeedNote(this.fileName, this.content, {this.modified});

  final String fileName;
  final String content;

  /// Last-modified time of the file; the app groups and sorts notes by it.
  final DateTime? modified;
}

/// Builds the repository the app runs on, so a test can wrap it.
typedef RepositoryBuilder =
    NoteRepositoryImpl Function(NoteFileStorage storage, NotesWatcher watcher);

/// Runs the real app on a temporary notes folder.
///
/// Every test gets its own folder, and the search index is reset to mirror
/// it, so tests never see each other's notes.
///
/// The search index always lives under `$HOME/.config/mechanix_apps/notes`
/// and cannot be redirected. Resetting it removes every indexed note,
/// including pin state, which is stored only there. Run the suite with a
/// throwaway HOME (see README), or set `MECHANIX_NOTES_IT_ALLOW_REAL_HOME=1`
/// to accept losing that state.
class NotesTestApp {
  NotesTestApp._(this.tester, this.notesDir, this.repository);

  final WidgetTester tester;
  final Directory notesDir;
  final NoteRepositoryImpl repository;

  static const _allowRealHomeVar = 'MECHANIX_NOTES_IT_ALLOW_REAL_HOME';

  /// Fails the test unless HOME is a temporary directory, or the developer
  /// opted in to resetting the real index.
  static void _guardHome() {
    final env = Platform.environment;
    if (env[_allowRealHomeVar] == '1') return;
    final home = env['HOME'] ?? '';
    final tmp = Directory.systemTemp.path;
    if (home.startsWith(tmp) || home.startsWith('/tmp/')) return;
    fail(
      'Integration tests reset the notes search index under '
      '\$HOME/.config/mechanix_apps/notes, which would delete the pin state '
      'of your real notes. Run them with a temporary HOME, e.g.\n'
      '  PUB_CACHE=~/.pub-cache RUSTUP_HOME=~/.rustup CARGO_HOME=~/.cargo '
      'HOME=\$(mktemp -d) flutter-elinux test <file> -d elinux-x11\n'
      'or set $_allowRealHomeVar=1 to run against your real HOME anyway.',
    );
  }

  /// Starts the app on a new temporary notes folder containing [seed].
  ///
  /// With [watchFolder] false the app does not watch its folder, so a change
  /// made on disk is only seen when the note is opened.
  static Future<NotesTestApp> launch(
    WidgetTester tester, {
    List<SeedNote> seed = const [],
    bool watchFolder = true,
    RepositoryBuilder? repositoryBuilder,
  }) async {
    _guardHome();
    // A tap that misses its widget fails the test instead of only warning.
    WidgetController.hitTestWarningShouldBeFatal = true;
    final dir = Directory.systemTemp.createTempSync('mechanix_notes_it_');
    final app = await _start(
      tester,
      dir,
      watchFolder: watchFolder,
      repositoryBuilder: repositoryBuilder,
      beforeSync: (repo) async {
        await _clearIndex(dir);
        for (final note in seed) {
          writeFile(dir, note.fileName, note.content, modified: note.modified);
        }
      },
    );
    addTearDown(app.close);
    return app;
  }

  static Future<NotesTestApp> _start(
    WidgetTester tester,
    Directory dir, {
    bool watchFolder = true,
    RepositoryBuilder? repositoryBuilder,
    Future<void> Function(NoteRepositoryImpl repo)? beforeSync,
  }) async {
    final storage = NoteFileStorage(notesDirectory: dir);
    final watcher = NotesWatcher(
      notesDirectory: watchFolder
          ? dir
          : Directory.systemTemp.createTempSync('mechanix_notes_unwatched_'),
    );
    final repo =
        repositoryBuilder?.call(storage, watcher) ??
        NoteRepositoryImpl(fileStorage: storage, notesWatcher: watcher);

    await repo.ensureStoreConnected();
    await beforeSync?.call(repo);
    // Index exactly what is in the folder (and drop anything that is not).
    await repo.syncNotesFromDisk();

    await tester.pumpWidget(
      RepositoryProvider<NoteRepository>.value(
        value: repo,
        child: BlocProvider(
          create: (_) => NotesBloc(noteRepository: repo),
          child: const NotesApp(),
        ),
      ),
    );
    final app = NotesTestApp._(tester, dir, repo);
    await app.waitFor(find.byIcon(Icons.add), reason: 'home screen');
    await app.pumpFor(const Duration(milliseconds: 300));
    return app;
  }

  /// Removes every note from the shared index (and its file, if it is in
  /// [dir]). Uses its own plain repository, so a test's repository that
  /// fails on purpose cannot get in the way.
  static Future<void> _clearIndex(Directory dir) async {
    final unwatched = Directory.systemTemp.createTempSync('mechanix_notes_cl_');
    final repo = NoteRepositoryImpl(
      fileStorage: NoteFileStorage(notesDirectory: dir),
      notesWatcher: NotesWatcher(notesDirectory: unwatched),
    );
    try {
      final indexed = await repo.getNotes(0, 1 << 20);
      if (indexed.isNotEmpty) {
        await repo.deleteNotes(indexed.map((n) => n.id).toList());
      }
    } finally {
      await repo.close();
      unwatched.deleteSync(recursive: true);
    }
  }

  bool _closed = false;

  /// Unmounts the app, empties the index and deletes the notes folder.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await repository.close();
    try {
      await _clearIndex(notesDir);
    } catch (_) {}
    if (notesDir.existsSync()) notesDir.deleteSync(recursive: true);
  }

  /// Quits and starts the app again on the same folder and index, like a
  /// user closing and reopening it. [whileClosed] runs in between, when the
  /// app is not watching the folder.
  Future<NotesTestApp> restart({void Function()? whileClosed}) async {
    _closed = true;
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await repository.close();
    whileClosed?.call();
    final app = await _start(tester, notesDir);
    addTearDown(app.close);
    return app;
  }

  // ---------------------------------------------------------------------------
  // Waiting
  // ---------------------------------------------------------------------------

  /// Pumps frames for [duration] of real time (file I/O, the folder watcher
  /// and the 2 s autosave all run in real time).
  Future<void> pumpFor(Duration duration) async {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Pumps until [condition] holds, failing after [timeout].
  Future<void> pumpUntil(
    bool Function() condition, {
    String reason = 'condition',
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final end = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(end)) {
        fail('Timed out after ${timeout.inSeconds}s waiting for $reason');
      }
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await tester.pump();
  }

  Future<void> waitFor(Finder finder, {String? reason, Duration? timeout}) =>
      pumpUntil(
        () => finder.evaluate().isNotEmpty,
        reason: reason ?? finder.describeMatch(Plurality.one),
        timeout: timeout ?? const Duration(seconds: 15),
      );

  Future<void> waitForAbsent(Finder finder, {String? reason}) => pumpUntil(
    () => finder.evaluate().isEmpty,
    reason: 'no ${reason ?? finder.describeMatch(Plurality.one)}',
  );

  // ---------------------------------------------------------------------------
  // Files
  // ---------------------------------------------------------------------------

  static File writeFile(
    Directory dir,
    String fileName,
    String content, {
    DateTime? modified,
  }) {
    final file = File('${dir.path}/$fileName')..writeAsStringSync(content);
    if (modified != null) file.setLastModifiedSync(modified);
    return file;
  }

  /// Writes a note file as another program would.
  File writeExternal(String fileName, String content, {DateTime? modified}) =>
      writeFile(notesDir, fileName, content, modified: modified);

  File file(String fileName) => File('${notesDir.path}/$fileName');

  /// Names of the note files in the folder, sorted.
  List<String> get noteFiles =>
      notesDir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where(NotesWatcher.isTrackedFile)
          .toList()
        ..sort();

  /// Waits until [fileName] exists and its content satisfies [matches].
  Future<String> waitForFile(
    String fileName, {
    bool Function(String content)? matches,
    String? reason,
  }) async {
    final f = file(fileName);
    await pumpUntil(
      () => f.existsSync() && (matches?.call(f.readAsStringSync()) ?? true),
      reason: reason ?? 'file $fileName',
    );
    return f.readAsStringSync();
  }

  Future<void> waitForFileGone(String fileName) => pumpUntil(
    () => !file(fileName).existsSync(),
    reason: '$fileName to be deleted',
  );

  // ---------------------------------------------------------------------------
  // Home screen
  // ---------------------------------------------------------------------------

  Finder get createButton => find.byIcon(Icons.add);

  /// The home card showing [title].
  Finder noteCard(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(HomeNoteCard));

  /// Titles of the home cards, top to bottom.
  List<String> get homeTitles => tester
      .widgetList<HomeNoteCard>(find.byType(HomeNoteCard))
      .map((c) => c.note.title)
      .toList();

  Future<void> waitForNoteCard(String title) =>
      waitFor(noteCard(title), reason: 'home card "$title"');

  Future<void> openNote(String title) async {
    await waitForNoteCard(title);
    await tester.tap(
      find.descendant(of: noteCard(title), matching: find.text(title)),
    );
    await waitForEditor();
  }

  /// Swipes [title]'s card open and taps its pin or delete action.
  Future<void> tapCardAction(String title, {required bool pin}) async {
    await waitForNoteCard(title);
    final card = tester.widget<HomeNoteCard>(noteCard(title));
    await tester.drag(noteCard(title), const Offset(-300, 0));
    await pumpFor(const Duration(milliseconds: 500));
    final key = pin
        ? 'pin_action_${card.note.id}'
        : 'delete_action_${card.note.id}';
    await tester.tap(find.byKey(ValueKey(key)));
    await pumpFor(const Duration(milliseconds: 500));
  }

  bool isPinnedOnHome(String title) =>
      tester.widget<HomeNoteCard>(noteCard(title)).note.isPinned;

  // ---------------------------------------------------------------------------
  // Editor
  // ---------------------------------------------------------------------------

  Finder get editor => find.byType(LiveMarkdownEditor);

  /// Waits for the editor and for its page transition to finish.
  Future<void> waitForEditor() async {
    await waitFor(editor, reason: 'note editor');
    await pumpFor(const Duration(milliseconds: 700));
  }

  Future<void> createNote() async {
    await tester.tap(createButton);
    await waitForEditor();
  }

  MarkdownEditorController get editorController =>
      tester.widget<LiveMarkdownEditor>(editor).controller;

  /// Gives the editor keyboard focus (needed for key presses).
  Future<void> focusEditor() async {
    MarkdownControllerProvider.of(
      tester.element(editor),
    ).focusNode.requestFocus();
    await tester.pump();
  }

  /// Replaces the editor's text, leaving the caret at the end.
  Future<void> setText(String text) async {
    editorController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    await tester.pump();
  }

  Future<void> select(int base, [int? extent]) async {
    editorController.selection = TextSelection(
      baseOffset: base,
      extentOffset: extent ?? base,
    );
    await tester.pump();
  }

  /// Selects the first occurrence of [text] in the editor.
  Future<void> selectText(String text) async {
    final start = editorController.text.indexOf(text);
    expect(start, isNot(-1), reason: '"$text" is not in the editor');
    await select(start, start + text.length);
  }

  Future<void> placeCaretAfter(String text) async {
    final start = editorController.text.indexOf(text);
    expect(start, isNot(-1), reason: '"$text" is not in the editor');
    await select(start + text.length);
  }

  /// Taps the back button and waits for the home screen.
  Future<void> goBack() async {
    await tester.tap(_buttonWith(_imageAsset(NotesIcon.backIcon)));
    await waitForAbsent(editor, reason: 'editor');
    await pumpFor(const Duration(milliseconds: 300));
  }

  /// Creates a note with [markdown] and returns to the home screen once it
  /// is saved.
  Future<void> createNoteWith(String markdown) async {
    await createNote();
    await setText(markdown);
    await goBack();
  }

  Future<void> pressKey(
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

  // Bottom toolbar ------------------------------------------------------------

  static const h1Button = Key('notes_text_contextual_button');
  static const h2Button = Key('notes_text_h2_button');
  static const bodyButton = Key('notes_text_body_button');
  static const boldButton = Key('notes_text_bold_button');
  static const italicButton = Key('notes_text_italic_button');
  static const strikethroughButton = Key('notes_text_strikethrough_button');
  static const codeButton = Key('notes_link_code_button');
  static const checklistButton = Key('notes_link_checklist_button');
  static const textModeToggle = Key('notes_text_toggle');
  static const linkModeToggle = Key('notes_link_toggle');

  Future<void> tapToolbar(Key button) async {
    if (find.byKey(button).evaluate().isEmpty) {
      final isLinkButton = button == codeButton || button == checklistButton;
      await tester.tap(
        find.byKey(isLinkButton ? linkModeToggle : textModeToggle),
      );
      await tester.pump();
    }
    await tester.tap(find.byKey(button));
    await tester.pump();
  }

  bool isToolbarActive(Key button) =>
      tester.widget<MechanixIconButton>(find.byKey(button)).isSelected ?? false;

  // Editor menu ---------------------------------------------------------------

  Future<void> openEditorMenu() async {
    await tester.tap(_buttonWith(_imageAsset(NotesIcon.moreVertIcon)));
    await pumpFor(const Duration(milliseconds: 400));
  }

  Future<void> tapEditorMenuItem(String label) async {
    await openEditorMenu();
    await tester.tap(find.text(label).last);
    await pumpFor(const Duration(milliseconds: 400));
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  Finder get searchField => find.byType(TextField);

  Future<void> openSearch() async {
    await tester.tap(_buttonWith(_imageIconAsset(NotesIcon.searchIcon)));
    await waitFor(searchField, reason: 'search field');
    await pumpFor(const Duration(milliseconds: 300));
  }

  Future<void> search(String query) async {
    await tester.enterText(searchField, query);
    // 250 ms debounce, then the index query.
    await pumpFor(const Duration(milliseconds: 600));
  }

  Finder get searchResults => find.byType(SearchResultTile);

  List<String> get searchResultTitles => tester
      .widgetList<SearchResultTile>(searchResults)
      .map((t) => t.note.title)
      .toList();

  Future<void> waitForSearchResults(Set<String> titles) => pumpUntil(
    () => searchResultTitles.toSet().containsAll(titles),
    reason: 'search results $titles (have $searchResultTitles)',
  );

  /// The visible snippet under [title]'s search result, as plain text.
  String? searchSnippet(String title) {
    final tile = find.ancestor(
      of: find.textContaining(title, findRichText: true),
      matching: find.byType(SearchResultTile),
    );
    final texts = tester
        .widgetList<RichText>(
          find.descendant(of: tile.first, matching: find.byType(RichText)),
        )
        .map((r) => r.text.toPlainText())
        .toList();
    return texts.length > 1 ? texts[1] : null;
  }

  Future<void> closeSearch() async {
    await tester.tap(_buttonWith(_imageAsset(NotesIcon.backIcon)));
    await waitForAbsent(searchField, reason: 'search screen');
  }

  // ---------------------------------------------------------------------------
  // Finders
  // ---------------------------------------------------------------------------

  static Finder _imageAsset(String asset) => find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == asset,
    description: 'image $asset',
  );

  static Finder _imageIconAsset(String asset) => find.byWidgetPredicate(
    (w) =>
        w is ImageIcon &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == asset,
    description: 'icon $asset',
  );

  static Finder imageAsset(String asset) => _imageAsset(asset);

  /// The icon button around [icon], which has a bigger tap target.
  static Finder _buttonWith(Finder icon) =>
      find.ancestor(of: icon, matching: find.byType(MechanixIconButton)).first;

  /// The icon button showing the image [asset].
  static Finder button(String asset) => _buttonWith(_imageAsset(asset));
}
