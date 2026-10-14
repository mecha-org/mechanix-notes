import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/features/notes/data/services/note_directory_watcher.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late NoteDirectoryWatcher watcher;
  late Set<String> internalWrites;
  late List<DateTime> callbackInvocations;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('note_dir_watcher_test_');
    internalWrites = <String>{};
    callbackInvocations = [];
  });

  tearDown(() {
    watcher.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('triggers callback when external .md file is created', () async {
    final completer = Completer<void>();
    watcher = NoteDirectoryWatcher(
      directory: tempDir,
      debounceDuration: const Duration(milliseconds: 100),
      isInternalWrite: (path) => internalWrites.contains(p.basename(path)),
      onDirectoryChanged: () async {
        callbackInvocations.add(DateTime.now());
        if (!completer.isCompleted) completer.complete();
      },
    );

    watcher.start();
    expect(watcher.isWatching, isTrue);

    // Create an external markdown file
    final testFile = File(p.join(tempDir.path, 'external_note.md'));
    await testFile.writeAsString('# External Note\nContent');

    await completer.future.timeout(const Duration(seconds: 3));
    expect(callbackInvocations.length, 1);
  });

  test('debounces multiple rapid filesystem events into a single callback', () async {
    int callCount = 0;
    watcher = NoteDirectoryWatcher(
      directory: tempDir,
      debounceDuration: const Duration(milliseconds: 150),
      isInternalWrite: (path) => internalWrites.contains(p.basename(path)),
      onDirectoryChanged: () async {
        callCount++;
      },
    );

    watcher.start();

    // Trigger rapid writes within the debounce window
    final file1 = File(p.join(tempDir.path, 'note1.md'));
    await file1.writeAsString('# Note 1');
    await Future.delayed(const Duration(milliseconds: 30));
    await file1.writeAsString('# Note 1 updated');
    await Future.delayed(const Duration(milliseconds: 30));
    final file2 = File(p.join(tempDir.path, 'note2.md'));
    await file2.writeAsString('# Note 2');

    // Wait past the debounce duration
    await Future.delayed(const Duration(milliseconds: 350));
    expect(callCount, 1);
  });

  test('ignores non-.md files', () async {
    bool called = false;
    watcher = NoteDirectoryWatcher(
      directory: tempDir,
      debounceDuration: const Duration(milliseconds: 100),
      isInternalWrite: (path) => internalWrites.contains(p.basename(path)),
      onDirectoryChanged: () async {
        called = true;
      },
    );

    watcher.start();

    final nonMdFile = File(p.join(tempDir.path, 'notes.txt'));
    await nonMdFile.writeAsString('Plain text');

    await Future.delayed(const Duration(milliseconds: 250));
    expect(called, isFalse);
  });

  test('ignores atomic temp files starting with ..tmp_', () async {
    bool called = false;
    watcher = NoteDirectoryWatcher(
      directory: tempDir,
      debounceDuration: const Duration(milliseconds: 100),
      isInternalWrite: (path) => internalWrites.contains(p.basename(path)),
      onDirectoryChanged: () async {
        called = true;
      },
    );

    watcher.start();

    final tmpFile = File(p.join(tempDir.path, '..tmp_saving.md'));
    await tmpFile.writeAsString('Temp content');

    await Future.delayed(const Duration(milliseconds: 250));
    expect(called, isFalse);
  });

  test('ignores internal writes', () async {
    bool called = false;
    internalWrites.add('internal_note.md');

    watcher = NoteDirectoryWatcher(
      directory: tempDir,
      debounceDuration: const Duration(milliseconds: 100),
      isInternalWrite: (path) => internalWrites.contains(p.basename(path)),
      onDirectoryChanged: () async {
        called = true;
      },
    );

    watcher.start();

    final internalFile = File(p.join(tempDir.path, 'internal_note.md'));
    await internalFile.writeAsString('# Internal Note');

    await Future.delayed(const Duration(milliseconds: 250));
    expect(called, isFalse);
  });

  test('stop prevents further callbacks', () async {
    bool called = false;
    watcher = NoteDirectoryWatcher(
      directory: tempDir,
      debounceDuration: const Duration(milliseconds: 100),
      isInternalWrite: (path) => internalWrites.contains(p.basename(path)),
      onDirectoryChanged: () async {
        called = true;
      },
    );

    watcher.start();
    watcher.stop();
    expect(watcher.isWatching, isFalse);

    final file = File(p.join(tempDir.path, 'after_stop.md'));
    await file.writeAsString('# Stopped');

    await Future.delayed(const Duration(milliseconds: 250));
    expect(called, isFalse);
  });
}
