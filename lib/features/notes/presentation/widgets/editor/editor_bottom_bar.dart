import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/bottom_bar/notes_text_link_control.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/markdown_controller_provider.dart';
import 'package:widgets/widgets.dart';

class EditorBottomBar extends StatefulWidget {
  const EditorBottomBar({super.key});

  @override
  State<EditorBottomBar> createState() => _EditorBottomBarState();
}

class _EditorBottomBarState extends State<EditorBottomBar> {
  static const int _flagH1 = 1 << 0;
  static const int _flagH2 = 1 << 1;
  static const int _flagChecklist = 1 << 2;
  static const int _flagCode = 1 << 3;
  static const int _flagBold = 1 << 4;
  static const int _flagItalic = 1 << 5;
  static const int _flagStrikethrough = 1 << 6;
  static const int _flagBody = 1 << 7;

  static final _hPrefixRegex = RegExp(r'^#{1,6}\s+');
  static final _taskPrefixRegex = RegExp(r'^[-+*]\s+\[[ xX]\]\s+');
  static final _bulletPrefixRegex = RegExp(r'^[-+*]\s+');
  static final _orderedPrefixRegex = RegExp(r'^\d+[.)]\s+');
  static final _quotePrefixRegex = RegExp(r'^>\s+');

  MarkdownEditorController? _controller;
  int _currentMask = _flagBody;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = MarkdownControllerProvider.maybeOf(
      context,
    )?.controller;
    if (newController != _controller) {
      _controller?.removeListener(_onControllerChanged);
      _controller = newController;
      _controller?.addListener(_onControllerChanged);
      _currentMask = _computeStyleMask();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final newMask = _computeStyleMask();
    if (newMask != _currentMask) {
      setState(() {
        _currentMask = newMask;
      });
    }
  }

  static String _stripLinePrefix(String line) {
    return line
        .replaceFirst(_hPrefixRegex, '')
        .replaceFirst(_taskPrefixRegex, '')
        .replaceFirst(_bulletPrefixRegex, '')
        .replaceFirst(_orderedPrefixRegex, '')
        .replaceFirst(_quotePrefixRegex, '');
  }

  ({int lineStart, int lineEnd, String currentLine, int clampedCaret})
  _getLineInfo(MarkdownEditorController controller) {
    final text = controller.text;
    final sel = controller.selection;
    final caret = sel.isValid ? sel.start : 0;
    final clampedCaret = caret.clamp(0, text.length);

    final lineStart = clampedCaret == 0
        ? 0
        : text.lastIndexOf('\n', clampedCaret - 1) + 1;
    final nextNewline = text.indexOf('\n', clampedCaret);
    final lineEnd = nextNewline < 0 ? text.length : nextNewline;
    final currentLine = text.substring(lineStart, lineEnd);
    return (
      lineStart: lineStart,
      lineEnd: lineEnd,
      currentLine: currentLine,
      clampedCaret: clampedCaret,
    );
  }

  int _computeStyleMask() {
    final controller = _controller;
    if (controller == null) return _flagBody;

    final info = _getLineInfo(controller);
    final currentLine = info.currentLine;
    final clampedCaret = info.clampedCaret;
    final sel = controller.selection;
    final text = controller.text;

    final doc = controller.document;
    final innermost = _findInnermostBlock(doc.blocks, clampedCaret);

    bool isH1 = false;
    bool isH2 = false;
    bool isHeading = false;
    if (innermost != null && innermost.type == MarkdownBlockType.heading) {
      isHeading = true;
      if (innermost.level == 1) {
        isH1 = true;
      } else {
        // H2, and H3..H6 mapped to H2 as subheading
        isH2 = true;
      }
    } else if (currentLine.startsWith('# ') && !currentLine.startsWith('## ')) {
      isH1 = true;
      isHeading = true;
    } else if (currentLine.startsWith('## ')) {
      isH2 = true;
      isHeading = true;
    } else if (currentLine.startsWith('### ') ||
        currentLine.startsWith('#### ') ||
        currentLine.startsWith('##### ') ||
        currentLine.startsWith('###### ')) {
      isH2 = true;
      isHeading = true;
    }

    final isChecklist = innermost?.type == MarkdownBlockType.taskListItem ||
        currentLine.trimLeft().startsWith('- [ ] ') ||
        currentLine.trimLeft().startsWith('- [x] ') ||
        currentLine.trimLeft().startsWith('- [X] ');

    final isCode = (innermost != null &&
            (innermost.type == MarkdownBlockType.fencedCode ||
                innermost.type == MarkdownBlockType.indentedCode)) ||
        currentLine.trim().startsWith('```');

    final isBody = !isHeading && !isChecklist && !isCode;

    final Set<MarkdownInlineType> styles;
    if (sel.isValid && !sel.isCollapsed) {
      styles = _selectionStyles(
        controller,
        sel.start.clamp(0, text.length),
        sel.end.clamp(0, text.length),
      );
    } else {
      final spans = _styleSpans(controller, clampedCaret, clampedCaret);
      styles = _caretStyles(spans, clampedCaret);
      final insideMarkers = _insideMarkers(controller, clampedCaret, spans);
      final empty = _emptyPairAt(
        controller,
        clampedCaret,
        insideMarkers: insideMarkers,
      );
      if (empty.bold) styles.add(MarkdownInlineType.bold);
      if (empty.italic) styles.add(MarkdownInlineType.italic);
      if (empty.strikethrough) styles.add(MarkdownInlineType.strikethrough);
    }

    final isBold = styles.contains(MarkdownInlineType.bold);
    final isItalic = styles.contains(MarkdownInlineType.italic);
    final isStrikethrough = styles.contains(MarkdownInlineType.strikethrough);

    var mask = 0;
    if (isH1) mask |= _flagH1;
    if (isH2) mask |= _flagH2;
    if (isChecklist) mask |= _flagChecklist;
    if (isCode) mask |= _flagCode;
    if (isBold) mask |= _flagBold;
    if (isItalic) mask |= _flagItalic;
    if (isStrikethrough) mask |= _flagStrikethrough;
    if (isBody) mask |= _flagBody;
    return mask;
  }

  static void _replaceLine(
    MarkdownEditorController controller,
    int lineStart,
    int lineEnd,
    String newLine,
    int clampedCaret,
  ) {
    final text = controller.text;
    final newText = text.replaceRange(lineStart, lineEnd, newLine);
    final delta = newLine.length - (lineEnd - lineStart);
    final newCaret = math.max(
      0,
      math.min(clampedCaret + delta, newText.length),
    );
    controller.applyEditingValue(
      TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCaret),
      ),
    );
  }

  static void _replaceRange(
    MarkdownEditorController controller,
    int start,
    int end,
    String replacement,
  ) {
    final text = controller.text;
    final newText = text.replaceRange(start, end, replacement);
    controller.applyEditingValue(
      TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: start,
          extentOffset: start + replacement.length,
        ),
      ),
    );
  }

  void _toggleHeader(int level) {
    final provider = MarkdownControllerProvider.maybeOf(context);
    if (provider == null) return;
    final controller = provider.controller;
    final info = _getLineInfo(controller);
    final isH1Active = (_currentMask & _flagH1) != 0;
    final isH2Active = (_currentMask & _flagH2) != 0;

    final prefix = '${'#' * level} ';
    if ((level == 1 && isH1Active) || (level == 2 && isH2Active)) {
      _replaceLine(
        controller,
        info.lineStart,
        info.lineEnd,
        _stripLinePrefix(info.currentLine),
        info.clampedCaret,
      );
    } else {
      final clean = _stripLinePrefix(info.currentLine);
      _replaceLine(
        controller,
        info.lineStart,
        info.lineEnd,
        '$prefix$clean',
        info.clampedCaret,
      );
    }
    provider.focusNode.requestFocus();
  }

  void _clearToParagraph() {
    final provider = MarkdownControllerProvider.maybeOf(context);
    if (provider == null) return;
    final controller = provider.controller;
    final info = _getLineInfo(controller);
    _replaceLine(
      controller,
      info.lineStart,
      info.lineEnd,
      _stripLinePrefix(info.currentLine),
      info.clampedCaret,
    );
    provider.focusNode.requestFocus();
  }

  void _toggleChecklist() {
    final provider = MarkdownControllerProvider.maybeOf(context);
    if (provider == null) return;
    final controller = provider.controller;
    final info = _getLineInfo(controller);
    final isChecklistActive = (_currentMask & _flagChecklist) != 0;

    if (isChecklistActive) {
      _replaceLine(
        controller,
        info.lineStart,
        info.lineEnd,
        _stripLinePrefix(info.currentLine),
        info.clampedCaret,
      );
    } else {
      final clean = _stripLinePrefix(info.currentLine);
      _replaceLine(
        controller,
        info.lineStart,
        info.lineEnd,
        '- [ ] $clean',
        info.clampedCaret,
      );
    }
    provider.focusNode.requestFocus();
  }

  void _toggleInline(String delimiter, MarkdownCommand command) {
    final provider = MarkdownControllerProvider.maybeOf(context);
    if (provider == null) return;
    final controller = provider.controller;
    final sel = controller.selection;
    final text = controller.text;

    if (sel.isValid && !sel.isCollapsed && sel.end <= text.length) {
      final selectedText = text.substring(sel.start, sel.end);
      final dLen = delimiter.length;
      if (selectedText.startsWith(delimiter) &&
          selectedText.endsWith(delimiter) &&
          selectedText.length >= 2 * dLen) {
        final unwrapped = selectedText.substring(
          dLen,
          selectedText.length - dLen,
        );
        _replaceRange(controller, sel.start, sel.end, unwrapped);
        provider.focusNode.requestFocus();
        return;
      }
    }
    if (sel.isValid && sel.isCollapsed) {
      final caret = sel.start.clamp(0, text.length);
      final dLen = delimiter.length;

      final spans = _styleSpans(controller, caret, caret);
      final insideMarkers = _insideMarkers(controller, caret, spans);

      // Second tap on an empty pair (`**|**`): remove it -> inactive.
      if (_hasEmptyPair(
        controller,
        caret,
        delimiter,
        insideMarkers: insideMarkers,
      )) {
        controller.applyEditingValue(
          TextEditingValue(
            text: text.replaceRange(caret - dLen, caret + dLen, ''),
            selection: TextSelection.collapsed(offset: caret - dLen),
          ),
        );
        provider.focusNode.requestFocus();
        return;
      }

      // Caret inside already-formatted text (`**abc|**`): step out past the
      // closing delimiter so further typing is unformatted.
      final type = _inlineTypeFor(command);
      final span = type == null
          ? null
          : spans
                .where(
                  (s) =>
                      s.type == type &&
                      s.outerStart < caret &&
                      caret < s.outerEnd,
                )
                .lastOrNull;
      if (span != null) {
        controller.applyEditingValue(
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: span.outerEnd),
          ),
        );
        provider.focusNode.requestFocus();
        return;
      }
    }

    controller.execute(command);
    provider.focusNode.requestFocus();
  }

  static MarkdownInlineType? _inlineTypeFor(MarkdownCommand command) {
    switch (command) {
      case MarkdownCommand.bold:
        return MarkdownInlineType.bold;
      case MarkdownCommand.italic:
        return MarkdownInlineType.italic;
      case MarkdownCommand.strikethrough:
        return MarkdownInlineType.strikethrough;
      default:
        return null;
    }
  }

  static const int _styleMaskBold = 1 << 0;
  static const int _styleMaskItalic = 1 << 1;
  static const int _styleMaskStrike = 1 << 2;

  static int _maskFor(MarkdownInlineType type) => switch (type) {
    MarkdownInlineType.bold => _styleMaskBold,
    MarkdownInlineType.italic => _styleMaskItalic,
    MarkdownInlineType.strikethrough => _styleMaskStrike,
    _ => 0,
  };

  static MarkdownBlockNode? _findInnermostBlock(
    List<MarkdownBlockNode> blocks,
    int caret,
  ) {
    for (final block in blocks) {
      if (block.range.start <= caret && caret <= block.range.end) {
        final inner = _findInnermostBlock(block.children, caret);
        return inner ?? block;
      }
    }
    return null;
  }

  static bool _isStyleType(MarkdownInlineType type) =>
      type == MarkdownInlineType.bold ||
      type == MarkdownInlineType.italic ||
      type == MarkdownInlineType.strikethrough;

  /// The letters a style node actually covers. When a style wraps exactly one
  /// other style (`***word***` = italic around bold), both cover the inner
  /// word, so they switch on and off together.
  static SourceRange _effectiveContent(MarkdownInlineNode node) {
    final children = node.children;
    if (children.length == 1 &&
        _isStyleType(children.first.type) &&
        children.first.range == node.contentRange) {
      return _effectiveContent(children.first);
    }
    return node.contentRange;
  }

  /// Visits every inline node in blocks touching `[from, to]`, descending into
  /// nested blocks (lists, checklists, quotes). [onNode] receives each node
  /// with the style bitmask of its ancestors and its outer marker range (shared
  /// with its parent when it exactly fills the parent's content).
  static void _visitInline(
    MarkdownEditorController controller,
    int from,
    int to,
    void Function(
      MarkdownInlineNode node,
      int ancestorMask,
      int outerStart,
      int outerEnd,
    )
    onNode,
  ) {
    void visitNodes(
      List<MarkdownInlineNode> nodes,
      MarkdownInlineNode? parent,
      int ancestorMask,
      int parentOuterStart,
      int parentOuterEnd,
    ) {
      for (final node in nodes) {
        if (node.range.end < from || node.range.start > to) continue;
        final fillsParent =
            parent != null &&
            _isStyleType(parent.type) &&
            node.range == parent.contentRange;
        final outerStart = fillsParent ? parentOuterStart : node.range.start;
        final outerEnd = fillsParent ? parentOuterEnd : node.range.end;
        onNode(node, ancestorMask, outerStart, outerEnd);
        final nextMask = _isStyleType(node.type)
            ? (ancestorMask | _maskFor(node.type))
            : ancestorMask;
        visitNodes(
          node.children,
          node,
          nextMask,
          outerStart,
          outerEnd,
        );
      }
    }

    void visitBlocks(List<MarkdownBlockNode> blocks) {
      for (final block in blocks) {
        if (block.range.end < from || block.range.start > to) continue;
        visitNodes(block.inlineNodes, null, 0, 0, 0);
        visitBlocks(block.children);
      }
    }

    visitBlocks(controller.document.blocks);
  }

  /// Style spans (bold / italic / strikethrough) touching `[from, to]`, with
  /// the letters they cover (`content*`) and their marker edges (`outer*`).
  static List<
    ({
      MarkdownInlineType type,
      int contentStart,
      int contentEnd,
      int outerStart,
      int outerEnd,
    })
  >
  _styleSpans(MarkdownEditorController controller, int from, int to) {
    final result =
        <
          ({
            MarkdownInlineType type,
            int contentStart,
            int contentEnd,
            int outerStart,
            int outerEnd,
          })
        >[];
    _visitInline(controller, from, to, (node, _, outerStart, outerEnd) {
      if (!_isStyleType(node.type)) return;
      final content = _effectiveContent(node);
      result.add((
        type: node.type,
        contentStart: content.start,
        contentEnd: content.end,
        outerStart: outerStart,
        outerEnd: outerEnd,
      ));
    });
    return result;
  }

  /// Styles active for a collapsed [caret]: a style is on when the caret is
  /// after at least one of its letters and no further than its last one,
  /// i.e. `contentStart < caret <= contentEnd`.
  static Set<MarkdownInlineType> _caretStyles(
    List<
      ({
        MarkdownInlineType type,
        int contentStart,
        int contentEnd,
        int outerStart,
        int outerEnd,
      })
    >
    spans,
    int caret,
  ) {
    return {
      for (final span in spans)
        if (span.contentStart < caret && caret <= span.contentEnd) span.type,
    };
  }

  /// Styles shared by every selected letter in `[start, end)`. Markers and
  /// other non-text characters are ignored; a selection with no letters has
  /// no active style.
  static Set<MarkdownInlineType> _selectionStyles(
    MarkdownEditorController controller,
    int start,
    int end,
  ) {
    int? commonMask;
    _visitInline(controller, start, end, (node, ancestorMask, _, _) {
      if (node.type != MarkdownInlineType.text) return;
      final overlaps =
          math.min(node.range.end, end) > math.max(node.range.start, start);
      if (!overlaps) return;
      commonMask =
          commonMask == null ? ancestorMask : (commonMask! & ancestorMask);
    });
    if (commonMask == null || commonMask == 0) return <MarkdownInlineType>{};
    return {
      if ((commonMask! & _styleMaskBold) != 0) MarkdownInlineType.bold,
      if ((commonMask! & _styleMaskItalic) != 0) MarkdownInlineType.italic,
      if ((commonMask! & _styleMaskStrike) != 0)
        MarkdownInlineType.strikethrough,
    };
  }

  static bool _hasEmptyPair(
    MarkdownEditorController controller,
    int caret,
    String delimiter, {
    bool? insideMarkers,
  }) {
    if (delimiter == '*' || delimiter == '**') {
      final pair = _emptyPairAt(
        controller,
        caret,
        insideMarkers: insideMarkers,
      );
      return delimiter == '**' ? pair.bold : pair.italic;
    }
    final isInside = insideMarkers ?? _insideMarkers(controller, caret);
    if (isInside) return false;
    final text = controller.text;
    final d = delimiter.length;
    return caret >= d &&
        caret + d <= text.length &&
        text.substring(caret - d, caret) == delimiter &&
        text.substring(caret, caret + d) == delimiter;
  }

  /// Whether [caret] sits strictly inside the opening or closing markers of
  /// parsed formatting, e.g. `*|*word**` or `***word*|**`.
  static bool _insideMarkers(
    MarkdownEditorController controller,
    int caret, [
    List<
      ({
        MarkdownInlineType type,
        int contentStart,
        int contentEnd,
        int outerStart,
        int outerEnd,
      })
    >?
    cachedSpans,
  ]) {
    final spans = cachedSpans ?? _styleSpans(controller, caret, caret);
    for (final s in spans) {
      if ((s.outerStart < caret && caret < s.contentStart) ||
          (s.contentEnd < caret && caret < s.outerEnd)) {
        return true;
      }
    }
    return false;
  }

  /// Detects empty delimiter pairs around [caret], e.g. `**|**`, `*|*`,
  /// `***|***` (bold + italic) or `~~|~~`. A caret inside the markers of
  /// already-formatted text (`*|*word**`) is not an empty pair.
  static ({bool bold, bool italic, bool strikethrough}) _emptyPairAt(
    MarkdownEditorController controller,
    int caret, {
    bool? insideMarkers,
  }) {
    final isInside = insideMarkers ?? _insideMarkers(controller, caret);
    if (isInside) {
      return (bold: false, italic: false, strikethrough: false);
    }
    final text = controller.text;
    int countBack(String ch) {
      var i = caret;
      while (i > 0 && text[i - 1] == ch) {
        i--;
      }
      return caret - i;
    }

    int countFwd(String ch) {
      var i = caret;
      while (i < text.length && text[i] == ch) {
        i++;
      }
      return i - caret;
    }

    // Only a balanced run is an empty pair: `**|**` is, but the caret inside
    // a marker run of formatted text (`*|**word***`) is not.
    int pair(String ch) {
      final back = countBack(ch);
      return back == countFwd(ch) ? back : 0;
    }

    final stars = pair('*');
    final tildes = pair('~');
    return (
      bold: stars >= 2,
      italic: stars == 1 || stars >= 3,
      strikethrough: tildes >= 2,
    );
  }

  void _toggleCodeBlock() {
    final provider = MarkdownControllerProvider.maybeOf(context);
    if (provider == null) return;
    provider.controller.execute(MarkdownCommand.fencedCode);
    provider.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final provider = MarkdownControllerProvider.maybeOf(context);

    Widget content;
    if (provider == null) {
      content = const NotesTextLinkControl();
    } else {
      content = NotesTextLinkControl(
        isTextContextualActive: (_currentMask & _flagH1) != 0,
        onTextContextualPressed: () => _toggleHeader(1),
        isH2Active: (_currentMask & _flagH2) != 0,
        onH2Pressed: () => _toggleHeader(2),
        isBodyActive: (_currentMask & _flagBody) != 0,
        onBodyPressed: _clearToParagraph,
        isBoldActive: (_currentMask & _flagBold) != 0,
        onBoldPressed: () => _toggleInline('**', MarkdownCommand.bold),
        isItalicActive: (_currentMask & _flagItalic) != 0,
        onItalicPressed: () => _toggleInline('*', MarkdownCommand.italic),
        isUnderlineActive: false,
        onUnderlinePressed: null,
        isStrikethroughActive: (_currentMask & _flagStrikethrough) != 0,
        onStrikethroughPressed: () =>
            _toggleInline('~~', MarkdownCommand.strikethrough),
        isChecklistActive: (_currentMask & _flagChecklist) != 0,
        onChecklistPressed: _toggleChecklist,
        isCodeActive: (_currentMask & _flagCode) != 0,
        onCodePressed: _toggleCodeBlock,
      );
    }

    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: context.colorScheme.surfaceContainer),
      child: content,
    );
  }
}
