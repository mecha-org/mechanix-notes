import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/services/indexing_service.dart';

void main() {
  group('IndexingService noteModelToDoc Tests', () {
    final service = IndexingService();

    test(
      'converts note content to clean plain text stripping markdown tokens',
      () {
        final note = NoteModel(
          id: 'blocks.md',
          title: 'blocks',
          content: '''
# blocks
... elephant
# Re Indexed
- [ ] checkbox
- [x] completed task
**bold** and `code`
''',
          previewText: 'elephant Re Indexed checkbox',
          updatedAt: DateTime(2026, 11, 24),
        );

        final doc = service.noteModelToDoc(note);

        expect(doc.id, 'blocks.md');
        expect(doc.title, 'blocks');
        expect(doc.previewText, 'elephant Re Indexed checkbox');

        // Verify markdown tokens are stripped from indexed content
        expect(doc.content.contains('- [ ]'), isFalse);
        expect(doc.content.contains('- [x]'), isFalse);
        expect(doc.content.contains('#'), isFalse);
        expect(doc.content.contains('**'), isFalse);
        expect(doc.content.contains('`'), isFalse);

        // Verify plain text words are preserved for indexing
        expect(doc.content.contains('checkbox'), isTrue);
        expect(doc.content.contains('Re Indexed'), isTrue);
        expect(doc.content.contains('elephant'), isTrue);
        expect(doc.content.contains('completed task'), isTrue);
      },
    );

    NoteModel note({
      String content = '',
      bool isPinned = false,
      DateTime? updatedAt,
    }) => NoteModel(
      id: 'note.md',
      title: 'Note',
      content: content,
      previewText: 'preview',
      isPinned: isPinned,
      updatedAt: updatedAt ?? DateTime(2026, 11, 24, 9, 30),
    );

    test('keeps code, link text, strikethrough and italic words', () {
      final doc = service.noteModelToDoc(
        note(
          content:
              '```\nfinal answer = 42;\n```\n'
              'see [the docs](https://example.com) and ~~old~~ *new* plan\n',
        ),
      );

      expect(doc.content, contains('final answer = 42;'));
      expect(doc.content, contains('the docs'));
      expect(doc.content, isNot(contains('https://example.com')));
      expect(doc.content, isNot(contains('```')));
      expect(doc.content, isNot(contains('~~')));
      expect(doc.content, contains('old'));
      expect(doc.content, contains('new plan'));
    });

    test('keeps snake_case words intact', () {
      final doc = service.noteModelToDoc(note(content: 'rename my_var_name'));

      expect(doc.content, contains('my_var_name'));
    });

    test('stores pin state and update time', () {
      final updated = DateTime(2026, 11, 24, 9, 30, 15, 123);
      final doc = service.noteModelToDoc(
        note(isPinned: true, updatedAt: updated),
      );

      expect(doc.isPinned, isTrue);
      expect(doc.updatedAt.toInt(), updated.millisecondsSinceEpoch);
    });
  });

  group('IndexingService metadata conversion', () {
    final service = IndexingService();
    final updated = DateTime(2026, 11, 24, 18, 5, 1, 500);

    test('noteModelToMetaData copies the list fields', () {
      final meta = IndexingService.noteModelToMetaData(
        NoteModel(
          id: 'Trip.md',
          title: 'Trip',
          content: '# Trip\nfull body is not needed for the list',
          previewText: 'full body',
          isPinned: true,
          updatedAt: updated,
        ),
      );

      expect(meta.id, 'Trip.md');
      expect(meta.title, 'Trip');
      expect(meta.previewText, 'full body');
      expect(meta.isPinned, isTrue);
      expect(meta.updatedAt, updated);
      expect(meta.snippet, isNull);
    });

    test('docToMetaData round-trips a document with its search snippet', () {
      final doc = service.noteModelToDoc(
        NoteModel(
          id: 'Trip.md',
          title: 'Trip',
          content: '# Trip\npack the passport',
          previewText: 'pack the passport',
          isPinned: false,
          updatedAt: updated,
        ),
      );

      final meta = service.docToMetaData(
        doc,
        snippet: 'pack the <b>passport</b>',
      );

      expect(meta.id, 'Trip.md');
      expect(meta.title, 'Trip');
      expect(meta.previewText, 'pack the passport');
      expect(meta.isPinned, isFalse);
      expect(meta.updatedAt, updated);
      expect(meta.snippet, 'pack the <b>passport</b>');
    });
  });
}
