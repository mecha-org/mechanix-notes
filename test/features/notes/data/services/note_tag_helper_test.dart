import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/utils/helper.dart';
import 'package:mechanix_notes/features/notes/data/services/note_tag_helper.dart';

void main() {
  group('NoteTagHelper Tests', () {
    const testId = '7b3f94e1-8899-4a21-9922-1234567890ab';

    test('appendTag appends tag with double newline to normal content', () {
      const content = '# Meeting Notes\n- Discuss project';
      final tagged = NoteTagHelper.appendTag(content, testId);

      expect(
        tagged,
        contains(
          '# Meeting Notes\n- Discuss project\n\n<!-- mechanix:id=$testId -->\n',
        ),
      );
    });

    test('appendTag works on empty content', () {
      final tagged = NoteTagHelper.appendTag('', testId);
      expect(tagged, equals('<!-- mechanix:id=$testId -->\n'));
    });

    test('appendTag replaces existing tag idempotently', () {
      const content = '# Title\n\n<!-- mechanix:id=old-id-123 -->\n';
      final tagged = NoteTagHelper.appendTag(content, testId);

      expect(tagged, equals('# Title\n\n<!-- mechanix:id=$testId -->\n'));
    });

    test('stripTag removes tag cleanly leaving original content', () {
      const content =
          '# Meeting Notes\n- Discuss project\n\n<!-- mechanix:id=$testId -->\n';
      final stripped = NoteTagHelper.stripTag(content);

      expect(stripped, equals('# Meeting Notes\n- Discuss project'));
    });

    test('extractId retrieves UUID correctly', () {
      const content = '# Meeting Notes\n- Item\n\n<!-- mechanix:id=$testId -->';
      expect(NoteTagHelper.extractId(content), equals(testId));
    });

    test('extractId returns null when no tag exists', () {
      const content = '# Meeting Notes\n- Just an ordinary markdown file';
      expect(NoteTagHelper.extractId(content), isNull);
    });

    test('markdownToPlainText strips HTML comments and mechanix tags', () {
      const content = '# Title\nBody text\n\n<!-- mechanix:id=$testId -->';
      final plain = markdownToPlainText(content);
      expect(plain.contains('mechanix:id'), isFalse);
      expect(plain.contains('<!--'), isFalse);
      expect(plain.trim(), equals('Title\nBody text'));
    });
  });
}
