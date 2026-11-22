import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Arrow-key navigation and selection for a single-line [TextField] on
/// flutter-elinux:
///
/// | Keys                  | Action                                  |
/// |-----------------------|-----------------------------------------|
/// | Shift + ← / →         | Extend the selection by one character   |
/// | Shift + ↑ / ↓         | Select to the start / end               |
/// | Ctrl + ← / →          | Move to the start / end of a word       |
/// | Ctrl + Shift + ← / →  | Extend the selection by one word        |
/// | Ctrl + ↑ / ↓          | Move to the start / end                 |
/// | Ctrl + Shift + ↑ / ↓  | Select to the start / end               |
///
/// Ctrl + → stops at the end of the word (Linux / macOS convention).
///
/// The elinux embedder moves the caret itself on arrow keys, ignoring Shift
/// and Ctrl, and sends that caret back to the framework, overwriting what
/// Flutter just did. (The note editor drops the same echo in its own input
/// client.) This widget handles these keys itself and, while Shift or Ctrl
/// is held, restores its result whenever the embedder overwrites it.
class ArrowKeySelection extends StatefulWidget {
  const ArrowKeySelection({
    super.key,
    required this.controller,
    required this.child,
  });

  final TextEditingController controller;
  final Widget child;

  @override
  State<ArrowKeySelection> createState() => _ArrowKeySelectionState();
}

class _ArrowKeySelectionState extends State<ArrowKeySelection> {
  static final RegExp _wordChar = RegExp(r'[\p{L}\p{N}_]', unicode: true);

  /// Selection when Shift / Ctrl went down, before the embedder could move it.
  TextSelection? _base;

  /// Selection set by the last arrow press handled here.
  TextSelection? _selection;

  String _text = '';

  @override
  void initState() {
    super.initState();
    _text = widget.controller.text;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(ArrowKeySelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _reset();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _reset() {
    _base = null;
    _selection = null;
    _text = widget.controller.text;
  }

  bool get _modifierHeld {
    final keyboard = HardwareKeyboard.instance;
    return keyboard.isShiftPressed || keyboard.isControlPressed;
  }

  void _onControllerChanged() {
    final value = widget.controller.value;
    if (value.text != _text) {
      // Typing (e.g. Shift + letter) starts over.
      _text = value.text;
      _selection = null;
      _base = null;
      return;
    }
    final selection = _selection;
    if (selection != null && _modifierHeld && value.selection != selection) {
      // The embedder's caret echo: put our result back.
      widget.controller.selection = selection;
    }
  }

  bool _isShiftOrControl(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.shiftLeft ||
      key == LogicalKeyboardKey.shiftRight ||
      key == LogicalKeyboardKey.shift ||
      key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight ||
      key == LogicalKeyboardKey.control;

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (_isShiftOrControl(key)) {
      if (event is KeyDownEvent && _selection == null) {
        _base = widget.controller.selection;
      } else if (event is KeyUpEvent && !_modifierHeld) {
        _base = null;
        _selection = null;
      }
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final isArrow =
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown;
    final keyboard = HardwareKeyboard.instance;
    if (!isArrow ||
        !_modifierHeld ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      // Any other key (e.g. Ctrl + A) acts on the field's real selection,
      // so stop restoring ours.
      _selection = null;
      _base = null;
      return KeyEventResult.ignored;
    }

    final extend = keyboard.isShiftPressed;
    final byWord = keyboard.isControlPressed;
    final text = widget.controller.text;
    var current = _selection ?? _base ?? widget.controller.selection;
    if (!current.isValid) {
      current = TextSelection.collapsed(offset: text.length);
    }

    final int target;
    if (key == LogicalKeyboardKey.arrowUp) {
      target = 0; // single-line field: the start
    } else if (key == LogicalKeyboardKey.arrowDown) {
      target = text.length; // single-line field: the end
    } else {
      final forward = key == LogicalKeyboardKey.arrowRight;
      if (byWord) {
        // Without Shift, a selection collapses and the move starts from
        // the edge in the direction of travel.
        final from = extend
            ? current.extentOffset
            : (forward ? current.end : current.start);
        target = forward
            ? _nextWordEnd(text, from)
            : _prevWordStart(text, from);
      } else {
        target = _nextCharacter(text, current.extentOffset, forward);
      }
    }

    final next = extend
        ? TextSelection(baseOffset: current.baseOffset, extentOffset: target)
        : TextSelection.collapsed(offset: target);
    _selection = next;
    widget.controller.selection = next;
    return KeyEventResult.handled;
  }

  bool _isWordChar(String text, int index) => _wordChar.hasMatch(text[index]);

  /// End of the word at or after [offset], skipping spaces / punctuation.
  int _nextWordEnd(String text, int offset) {
    var i = offset;
    while (i < text.length && !_isWordChar(text, i)) {
      i++;
    }
    while (i < text.length && _isWordChar(text, i)) {
      i++;
    }
    return i;
  }

  /// Start of the word at or before [offset], skipping spaces / punctuation.
  int _prevWordStart(String text, int offset) {
    var i = offset;
    while (i > 0 && !_isWordChar(text, i - 1)) {
      i--;
    }
    while (i > 0 && _isWordChar(text, i - 1)) {
      i--;
    }
    return i;
  }

  int _nextCharacter(String text, int offset, bool forward) {
    final boundary = CharacterBoundary(text);
    if (forward) {
      return boundary.getTrailingTextBoundaryAt(offset) ?? text.length;
    }
    return offset == 0 ? 0 : boundary.getLeadingTextBoundaryAt(offset - 1) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }
}
