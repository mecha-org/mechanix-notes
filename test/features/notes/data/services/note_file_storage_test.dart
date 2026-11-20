import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/exceptions/storage_exception.dart';
import 'package:mechanix_notes/features/notes/data/services/note_file_storage.dart';

void main() {
  late Directory tempDir;
  late NoteFileStorage storage;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('note_file_storage_test_');
    storage = NoteFileStorage(notesDirectory: tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('sanitizeFileName', () {
    test('cleans leading hashes and whitespace', () {
      expect(NoteFileStorage.sanitizeFileName('# My Note'), 'My Note');
      expect(
        NoteFileStorage.sanitizeFileName('### Deep Heading'),
        'Deep Heading',
      );
    });

    test('replaces illegal characters with underscores', () {
      expect(
        NoteFileStorage.sanitizeFileName('What/is:this*file?'),
        'What_is_this_file',
      );
    });

    test(
      'falls back to untitled when title is empty or only special characters',
      () {
        expect(NoteFileStorage.sanitizeFileName(''), 'untitled');
        expect(NoteFileStorage.sanitizeFileName('    '), 'untitled');
        expect(NoteFileStorage.sanitizeFileName('###'), 'untitled');
        expect(NoteFileStorage.sanitizeFileName('...'), 'untitled');
      },
    );

    test('clamps long title to 100 characters', () {
      final longTitle = 'a' * 150;
      final sanitized = NoteFileStorage.sanitizeFileName(longTitle);
      expect(sanitized.length, 100);
    });
  });

  group('isFileNameForTitle', () {
    test('accepts the exact name and numbered variants', () {
      expect(NoteFileStorage.isFileNameForTitle('Title.md', 'Title'), isTrue);
      expect(
        NoteFileStorage.isFileNameForTitle('Title (3).md', '# Title'),
        isTrue,
      );
    });

    test('rejects other names', () {
      expect(NoteFileStorage.isFileNameForTitle('Other.md', 'Title'), isFalse);
      expect(
        NoteFileStorage.isFileNameForTitle('Title 2.md', 'Title'),
        isFalse,
      );
    });
  });

  group('createNoteFile', () {
    test('writes content atomically and reads back accurately', () async {
      const content =
          '# Title\n\n- [ ] Task 1\n- [x] Task 2\n\n```dart\nvar x = 1;\n```';
      final fileName = await storage.createNoteFile(
        title: 'Title',
        markdown: content,
      );

      expect(fileName, 'Title.md');
      expect(await storage.readNoteContent(fileName), content);
    });

    test('uses untitled.md for an empty title', () async {
      expect(
        await storage.createNoteFile(title: '', markdown: 'x'),
        'untitled.md',
      );
    });

    test('numbers the name when another note already has it', () async {
      File('${tempDir.path}/untitled.md').writeAsStringSync('existing');
      expect(
        await storage.createNoteFile(title: '', markdown: 'a'),
        'untitled (1).md',
      );
      expect(
        await storage.createNoteFile(title: '', markdown: 'b'),
        'untitled (2).md',
      );
      expect(await storage.readNoteContent('untitled.md'), 'existing');
    });

    test(
      'concurrent creates with the same title never overwrite each other',
      () async {
        final names = await Future.wait([
          for (var i = 0; i < 5; i++)
            storage.createNoteFile(title: 'Same', markdown: 'Write $i'),
        ]);

        expect(names.toSet().length, 5);
        final contents = {
          for (final n in names) await storage.readNoteContent(n),
        };
        expect(contents, {for (var i = 0; i < 5; i++) 'Write $i'});
      },
    );
  });

  group('updateNoteFile', () {
    test('overwrites in place when the title is unchanged', () async {
      final name = await storage.createNoteFile(
        title: 'Shopping',
        markdown: 'Milk',
      );
      final updated = await storage.updateNoteFile(
        fileName: name,
        title: 'Shopping',
        markdown: 'Milk, Bread',
      );

      expect(updated, name);
      expect(await storage.readNoteContent(name), 'Milk, Bread');
    });

    test('keeps a numbered name whose base still matches the title', () async {
      File('${tempDir.path}/Shopping (2).md').writeAsStringSync('old');
      final updated = await storage.updateNoteFile(
        fileName: 'Shopping (2).md',
        title: 'Shopping',
        markdown: 'new',
      );
      expect(updated, 'Shopping (2).md');
    });

    test('renames file when title changes and removes old file', () async {
      final oldName = await storage.createNoteFile(
        title: 'Old Title',
        markdown: 'Content 1',
      );
      final newName = await storage.updateNoteFile(
        fileName: oldName,
        title: 'New Title',
        markdown: 'Content 2',
      );

      expect(newName, 'New Title.md');
      expect(await storage.noteFileExists(oldName), isFalse);
      expect(await storage.readNoteContent(newName), 'Content 2');
    });

    test('rename numbers the name if another note already has it', () async {
      File('${tempDir.path}/Taken.md').writeAsStringSync('other note');
      final name = await storage.createNoteFile(title: 'Mine', markdown: 'a');
      final renamed = await storage.updateNoteFile(
        fileName: name,
        title: 'Taken',
        markdown: 'b',
      );

      expect(renamed, 'Taken (1).md');
      expect(await storage.readNoteContent('Taken.md'), 'other note');
      expect(await storage.noteFileExists(name), isFalse);
    });

    test(
      'throws NoteFileMissingException and writes nothing if the file is gone',
      () async {
        File('${tempDir.path}/Hello.md').writeAsStringSync('other');
        await expectLater(
          storage.updateNoteFile(
            fileName: 'gone.md',
            title: 'Hello',
            markdown: 'x',
          ),
          throwsA(isA<NoteFileMissingException>()),
        );
        final names = tempDir.listSync().map((e) => e.uri.pathSegments.last);
        expect(names, ['Hello.md']);
      },
    );
  });

  group('deleteNoteFile', () {
    test('deletes existing file', () async {
      final fileName = await storage.createNoteFile(
        title: 'To Delete',
        markdown: 'bye',
      );
      expect(await storage.noteFileExists(fileName), isTrue);

      await storage.deleteNoteFile(fileName);
      expect(await storage.noteFileExists(fileName), isFalse);
    });
  });

  group('getFileLastModified', () {
    test('returns null when file does not exist', () async {
      expect(await storage.getFileLastModified('non_existent.md'), isNull);
    });

    test('returns modified timestamp for existing file', () async {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final fileName = await storage.createNoteFile(
        title: 'Timestamp Note',
        markdown: 'Check timestamp',
      );
      final modified = await storage.getFileLastModified(fileName);

      expect(modified, isNotNull);
      expect(modified!.isAfter(before), isTrue);
    });
  });
}
