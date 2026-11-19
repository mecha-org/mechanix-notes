import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/utils/helper.dart';

void main() {
  group('markdownToPlainText Tests', () {
    test('returns empty string for empty input', () {
      expect(markdownToPlainText(''), equals(''));
    });

    test('preserves snake_case identifiers without stripping underscores', () {
      const input =
          'Check my_variable_name and user_id_123 in parse_json_data.';
      final result = markdownToPlainText(input);
      expect(
        result,
        equals('Check my_variable_name and user_id_123 in parse_json_data.'),
      );
    });

    test('preserves uppercase constants with underscores', () {
      const input = 'Value of MAX_BUFFER_SIZE and DEFAULT_TIMEOUT_MS.';
      final result = markdownToPlainText(input);
      expect(
        result,
        equals('Value of MAX_BUFFER_SIZE and DEFAULT_TIMEOUT_MS.'),
      );
    });

    test('correctly strips standalone underscore italics', () {
      const input = 'This is _italic text_ and another _word_ here.';
      final result = markdownToPlainText(input);
      expect(result, equals('This is italic text and another word here.'));
    });

    test('correctly strips asterisk italics', () {
      const input = 'This is *italic text* and another *word* here.';
      final result = markdownToPlainText(input);
      expect(result, equals('This is italic text and another word here.'));
    });

    test('correctly strips bold text with asterisks and underscores', () {
      const input = 'This is **bold text** and __underscore bold__.';
      final result = markdownToPlainText(input);
      expect(result, equals('This is bold text and underscore bold.'));
    });

    test('correctly strips headers', () {
      const input = '# Header 1\n## Header 2\n### Header 3\nContent';
      final result = markdownToPlainText(input);
      expect(result.trim(), equals('Header 1\nHeader 2\nHeader 3\nContent'));
    });

    test('correctly strips links and images', () {
      const input =
          'Visit [Google](https://google.com) and view ![Logo](https://img.png).';
      final result = markdownToPlainText(input);
      expect(result, equals('Visit Google and view Logo.'));
    });

    test('correctly strips fenced and inline code', () {
      const input = '```dart\nfinal x = 42;\n```\nAlso `inline_code_call()`.';
      final result = markdownToPlainText(input);
      expect(result.trim(), equals('final x = 42;\nAlso inline_code_call().'));
    });

    test('correctly strips checklists, bullet lists, and ordered lists', () {
      const input =
          '- [ ] Todo item\n- [x] Done item\n* Bullet item\n1. Numbered item';
      final result = markdownToPlainText(input);
      expect(
        result.trim(),
        equals('Todo item\nDone item\nBullet item\nNumbered item'),
      );
    });

    test('correctly strips blockquotes and horizontal rules', () {
      const input = '> Quote line\n---\nNormal text';
      final result = markdownToPlainText(input);
      expect(
        result.replaceAll(RegExp(r'\n+'), '\n').trim(),
        equals('Quote line\nNormal text'),
      );
    });

    test('correctly strips strikethrough, highlights, and HTML comments', () {
      const input = '~~deleted~~ and ==highlighted== <!-- mechanix:id=123 -->';
      final result = markdownToPlainText(input);
      expect(result.trim(), equals('deleted and highlighted'));
    });
  });

  group('extractTitleAndPreviewFromMarkdown Tests', () {
    for (final c in const [
      ('# Markdown **Stress** Test', 'Markdown Stress Test'),
      ('# ***Bold Italic*** Title', 'Bold Italic Title'),
      ('# *Italic* and ~~strike~~', 'Italic and strike'),
      ('# Title with `code` and ==mark==', 'Title with code and mark'),
      ('# [Linked](https://example.com) title', 'Linked title'),
    ]) {
      test('H1 title strips inline formatting: ${c.$1}', () {
        final (title, _) = extractTitleAndPreviewFromMarkdown('${c.$1}\nBody');
        expect(title, c.$2);
      });
    }

    test(
      'extracts H1 title and produces clean plain preview text without markdown tokens',
      () {
        const input = '''
# Full Feature Showcase

This note demonstrates all formatting features supported by **Mechanix Notes** and Obsidian.

1. Text Styling

You can format text with:
- **Bold text** for emphasis
- *Italicized text* for subtleties
- ~~Strikethrough text~~ for crossed-out ideas
- Inline `code snippets` for commands or variables
- Hyperlinks: [Mechanix Notes](https://example.com)
<!-- mechanix:id=test-id -->
''';

        final (title, preview) = extractTitleAndPreviewFromMarkdown(input);

        expect(title, equals('Full Feature Showcase'));
        expect(preview, isNot(contains('**')));
        expect(preview, isNot(contains('~~')));
        expect(preview, isNot(contains('`')));
        expect(preview, isNot(contains('<!--')));
        expect(preview, isNot(contains('https://example.com')));
        expect(preview, contains('Mechanix Notes and Obsidian'));
        expect(preview, contains('Bold text for emphasis'));
        expect(preview, contains('Italicized text for subtleties'));
      },
    );

    test('list-only note sets empty title and clean list preview', () {
      const input = '''
- First task
- Second task with **important** note
''';

      final (title, preview) = extractTitleAndPreviewFromMarkdown(
        input,
        fallbackTitle: 'fallback.md',
      );

      expect(title, equals('fallback.md'));
      expect(preview, isNot(contains('- ')));
      expect(preview, isNot(contains('**')));
      expect(preview, contains('First task'));
      expect(preview, contains('Second task with important note'));
    });

    test('single line note uses that line as title with empty preview', () {
      const input = 'Only One Line';
      final (title, preview) = extractTitleAndPreviewFromMarkdown(input);
      expect(title, equals('Only One Line'));
      expect(preview, isEmpty);
    });

    test('first line is the title with or without #', () {
      expect(extractTitleAndPreviewFromMarkdown('# hello'), ('hello', ''));
      expect(extractTitleAndPreviewFromMarkdown('hello'), ('hello', ''));
      expect(extractTitleAndPreviewFromMarkdown('hello\nworld'), (
        'hello',
        'world',
      ));
    });

    test('single line note ignores fallback title', () {
      final (title, preview) = extractTitleAndPreviewFromMarkdown(
        ' \nbody text',
        fallbackTitle: 'Old Title',
      );
      expect(title, equals('body text'));
      expect(preview, isEmpty);
    });
  });
}
