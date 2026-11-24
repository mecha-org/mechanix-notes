import 'package:flutter/material.dart';

class SearchTextHighlighter {
  static TextSpan highlight({
    required String text,
    required String query,
    required TextStyle baseStyle,
    required TextStyle highlightStyle,
  }) {
    if (text.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = trimmedQuery.toLowerCase();

    final spans = <TextSpan>[];
    var start = 0;
    var index = lowerText.indexOf(lowerQuery, start);

    if (index == -1) {
      return TextSpan(text: text, style: baseStyle);
    }

    while (index != -1) {
      // Add unhighlighted span before the match
      if (index > start) {
        spans.add(
          TextSpan(text: text.substring(start, index), style: baseStyle),
        );
      }

      // Add highlighted matched span
      final matchEnd = index + lowerQuery.length;
      spans.add(
        TextSpan(text: text.substring(index, matchEnd), style: highlightStyle),
      );

      start = matchEnd;
      index = lowerText.indexOf(lowerQuery, start);
    }

    // Add remaining trailing unhighlighted text
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }

    return TextSpan(children: spans);
  }

  static String cleanSnippet(String text, {String? title}) {
    if (text.isEmpty) return text;
    // Strip leading '#' characters, e.g. '# blocks' -> 'blocks', '... # blocks' -> '... blocks'
    var cleaned = text.replaceFirstMapped(
      RegExp(r'^(\s*(?:\.\.\.\s*)?)#+\s*'),
      (match) => match.group(1) ?? '',
    );

    if (title != null && title.trim().isNotEmpty) {
      final trimmedTitle = title.trim();
      final escapedTitle = RegExp.escape(trimmedTitle);
      final titlePattern = RegExp(
        r'^(?:\.\.\.\s*)?(?:<b>\s*' +
            escapedTitle +
            r'\s*</b>|' +
            escapedTitle +
            r')(?:\s*[:\-–—]\s*|\s+)',
        caseSensitive: false,
      );

      final stripped = cleaned.replaceFirst(titlePattern, '');
      if (stripped != cleaned) {
        cleaned = stripped.trim();
      }
    }

    return cleaned;
  }

  /// Parses and highlights text containing `<b>...</b>` tags (e.g. from Tantivy snippet).
  /// Text inside `<b>...</b>` is highlighted with [highlightStyle], everything else with [baseStyle].
  /// If no `<b>` tags exist, falls back to standard query highlighting.
  static TextSpan highlightSnippet({
    required String text,
    required String query,
    required TextStyle baseStyle,
    required TextStyle highlightStyle,
  }) {
    if (text.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    if (!text.contains('<b>') || !text.contains('</b>')) {
      return highlight(
        text: text,
        query: query,
        baseStyle: baseStyle,
        highlightStyle: highlightStyle,
      );
    }

    final spans = <TextSpan>[];
    var cursor = 0;

    while (cursor < text.length) {
      final openTag = text.indexOf('<b>', cursor);
      if (openTag == -1) {
        spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
        break;
      }

      if (openTag > cursor) {
        spans.add(
          TextSpan(text: text.substring(cursor, openTag), style: baseStyle),
        );
      }

      final closeTag = text.indexOf('</b>', openTag + 3);
      if (closeTag == -1) {
        // Malformed closing tag, take remainder as normal text
        spans.add(
          TextSpan(text: text.substring(openTag + 3), style: baseStyle),
        );
        break;
      }

      final matchedText = text.substring(openTag + 3, closeTag);
      if (matchedText.isNotEmpty) {
        spans.add(TextSpan(text: matchedText, style: highlightStyle));
      }

      cursor = closeTag + 4;
    }

    return TextSpan(children: spans);
  }
}
