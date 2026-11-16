import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/features/notes/data/services/note_file_storage.dart';
import 'package:mechanix_notes/features/notes/data/services/notes_watcher.dart';

void main() {
  group('NotesWatcher.isTrackedFile', () {
    test('identifies valid markdown files', () {
      expect(NotesWatcher.isTrackedFile('/notes/hello.md'), isTrue);
      expect(NotesWatcher.isTrackedFile('/notes/My Long Note.md'), isTrue);
      expect(NotesWatcher.isTrackedFile('relative_note.md'), isTrue);
    });

    test('ignores hidden files and directories', () {
      expect(NotesWatcher.isTrackedFile('/notes/.mechanix/state.json'), isFalse);
      expect(NotesWatcher.isTrackedFile('/notes/.hidden.md'), isFalse);
      expect(NotesWatcher.isTrackedFile('/notes/.obsidian/app.json'), isFalse);
    });

    test('ignores temporary atomic write files', () {
      expect(NotesWatcher.isTrackedFile('/notes/..tmp_12345.md'), isFalse);
      expect(NotesWatcher.isTrackedFile('/notes/..tmp_state_0.json'), isFalse);
    });

    test('ignores non-markdown extensions', () {
      expect(NotesWatcher.isTrackedFile('/notes/image.png'), isFalse);
      expect(NotesWatcher.isTrackedFile('/notes/doc.txt'), isFalse);
      expect(NotesWatcher.isTrackedFile('/notes/data.json'), isFalse);
    });
  });

  group('NotesWatcher live filesystem events', () {
    late Directory tempDir;
    late NotesWatcher watcher;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('notes_watcher_test_');
      watcher = NotesWatcher(
        notesDirectory: tempDir,
        debounceDuration: const Duration(milliseconds: 50),
      );
      await watcher.start();
    });

    tearDown(() async {
      await watcher.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('emits event when a markdown file is created externally', () async {
      final file = File('${tempDir.path}/external.md');

      final eventFuture = watcher.events.firstWhere(
        (e) => e.fileName == 'external.md',
      );

      await file.writeAsString('# Hello World');

      final event = await eventFuture.timeout(const Duration(seconds: 3));
      expect(
        event.type,
        anyOf(NotesWatcherEventType.create, NotesWatcherEventType.modify),
      );
      expect(event.fileName, equals('external.md'));
    });

    test('emits delete event when a markdown file is deleted', () async {
      final file = File('${tempDir.path}/to_delete.md');
      await file.writeAsString('Goodbye');

      // Wait briefly for create event to settle
      await Future.delayed(const Duration(milliseconds: 100));

      final deleteEventFuture = watcher.events.firstWhere(
        (e) => e.fileName == 'to_delete.md' && e.type == NotesWatcherEventType.delete,
      );

      await file.delete();

      final event = await deleteEventFuture.timeout(const Duration(seconds: 3));
      expect(event.type, equals(NotesWatcherEventType.delete));
      expect(event.fileName, equals('to_delete.md'));
    });

    test('suppresses self-writes recorded via NoteFileStorage', () async {
      final file = File('${tempDir.path}/internal.md');
      await file.writeAsString('# Self Write');
      final stat = await file.stat();

      // Record self-write
      NoteFileStorage.recordSelfWrite('internal.md', stat.modified);

      var receivedEvent = false;
      final sub = watcher.events.listen((e) {
        if (e.fileName == 'internal.md') {
          receivedEvent = true;
        }
      });

      // Wait past the debounce duration
      await Future.delayed(const Duration(milliseconds: 250));
      await sub.cancel();

      expect(receivedEvent, isFalse);
    });
  });
}

