import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechanix_notes/core/exceptions/storage_exception.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository_impl.dart';

import 'notes_test_app.dart';

/// The real repository, except that loading the note list fails with
/// [error]. Neither failure can be produced on demand with real storage:
/// the index lock is per process and the index opens on any writable HOME.
class _FailingListRepository extends NoteRepositoryImpl {
  _FailingListRepository(this.error, {super.fileStorage, super.notesWatcher});

  final Object error;

  @override
  Stream<List<NoteMetaData>> watchNotes() => Stream.error(error);
}

/// The real repository, except that deleting notes fails. The real
/// [NoteRepositoryImpl.deleteNotes] swallows its own errors.
class _FailingDeleteRepository extends NoteRepositoryImpl {
  _FailingDeleteRepository({super.fileStorage, super.notesWatcher});

  @override
  Future<void> deleteNotes(List<String> ids) async =>
      throw const FileSystemException('Permission denied');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Error messages', () {
    testWidgets('a second running copy shows "app already running"', (
      tester,
    ) async {
      await NotesTestApp.launch(
        tester,
        repositoryBuilder: (storage, watcher) => _FailingListRepository(
          DatabaseLockedException(),
          fileStorage: storage,
          notesWatcher: watcher,
        ),
      );

      expect(
        find.text('Another instance of the app is already running.'),
        findsOneWidget,
      );
    });

    testWidgets('notes that fail to load show an error', (tester) async {
      await NotesTestApp.launch(
        tester,
        repositoryBuilder: (storage, watcher) => _FailingListRepository(
          Exception('index unreadable'),
          fileStorage: storage,
          notesWatcher: watcher,
        ),
      );

      expect(
        find.text('Failed to load notes. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('a note that cannot be saved shows "Failed to save note"', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(
        tester,
        seed: const [SeedNote('Locked.md', '# Locked\nbefore\n')],
      );
      await app.openNote('Locked');
      await app.setText('# Locked\nafter');

      // The folder and file become read-only, so the save cannot write.
      await Process.run('chmod', ['a-w', app.notesDir.path]);
      await Process.run('chmod', ['a-w', app.file('Locked.md').path]);
      addTearDown(() async {
        await Process.run('chmod', ['u+w', app.notesDir.path]);
        await Process.run('chmod', ['u+w', app.file('Locked.md').path]);
      });

      await tester.tap(NotesTestApp.button(NotesIcon.backIcon));
      await app.waitFor(find.text('Failed to save note'));

      // The editor is replaced by the error screen; the file is untouched.
      expect(find.text('Go Back'), findsOneWidget);
      expect(app.file('Locked.md').readAsStringSync(), '# Locked\nbefore\n');
    });

    testWidgets('opening a note whose file is gone shows "Note not found"', (
      tester,
    ) async {
      // Not watching the folder, so the card is still shown after the file
      // is removed, as when a deletion has not been noticed yet.
      final app = await NotesTestApp.launch(
        tester,
        watchFolder: false,
        seed: const [
          SeedNote('Gone.md', '# Gone\n'),
          SeedNote('Here.md', '# Here\n'),
        ],
      );
      await app.waitForNoteCard('Gone');
      app.file('Gone.md').deleteSync();

      await tester.tap(find.text('Gone'));
      await app.waitFor(find.text('Note not found'));

      // Back on the home screen, without the missing note.
      await app.waitForAbsent(app.editor, reason: 'editor');
      await app.waitForAbsent(app.noteCard('Gone'));
      expect(app.homeTitles, ['Here']);
    });

    testWidgets('a failed delete shows an error', (tester) async {
      final app = await NotesTestApp.launch(
        tester,
        seed: const [SeedNote('Stuck.md', '# Stuck\n')],
        repositoryBuilder: (storage, watcher) => _FailingDeleteRepository(
          fileStorage: storage,
          notesWatcher: watcher,
        ),
      );

      await app.tapCardAction('Stuck', pin: false);
      await tester.tap(find.text('DELETE'));
      await app.waitFor(find.text('Failed to delete notes. Please try again.'));
      expect(app.file('Stuck.md').existsSync(), isTrue);
    });
  });
}
