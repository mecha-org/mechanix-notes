import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/core/utils/quill_editor_styles.dart';
import 'package:widgets/widgets.dart';

class QuillEditorCheckbox extends StatefulWidget {
  final QuillController controller;
  final Node node;
  final LeadingConfig config;
  final bool isChecked;

  const QuillEditorCheckbox({
    super.key,
    required this.controller,
    required this.node,
    required this.config,
    required this.isChecked,
  });

  @override
  State<QuillEditorCheckbox> createState() => _QuillEditorCheckboxState();
}

class _QuillEditorCheckboxState extends State<QuillEditorCheckbox> {
  bool _isPressed = false;

  void _onTap() {
    final nextState = !widget.isChecked;
    _applyStrikethrough(widget.controller, widget.node, nextState);
    widget.config.onCheckboxTap(nextState);
  }

  void _applyStrikethrough(
    QuillController controller,
    Node node,
    bool apply,
  ) {
    try {
      final offset = node.documentOffset;
      final length = node.length - 1; // Exclude trailing newline character

      if (length > 0) {
        if (apply) {
          controller.formatText(offset, length, Attribute.strikeThrough);
        } else {
          controller.formatText(
            offset,
            length,
            Attribute.clone(Attribute.strikeThrough, null),
          );
        }
      }
    } catch (e, stack) {
      AppLogger.e('Failed to apply strikethrough: $e', error: e, stack: stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final pressedColor = colorScheme.primary.withValues(alpha: 0.28);
    final hoverColor = colorScheme.primary.withValues(alpha: 0.08);

    return FocusPreserveButton(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: 32,
          alignment: Alignment.topLeft,
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: SizedBox(
            width: 18,
            height: 18,
            child: InkResponse(
              onTap: _onTap,
              radius: 18,
              containedInkWell: false,
              highlightShape: BoxShape.circle,
              splashColor: pressedColor,
              highlightColor: pressedColor,
              hoverColor: hoverColor,
              onTapDown: (_) {
                if (!_isPressed) {
                  setState(() => _isPressed = true);
                }
              },
              onTapUp: (_) {
                if (_isPressed) {
                  setState(() => _isPressed = false);
                }
              },
              onTapCancel: () {
                if (_isPressed) {
                  setState(() => _isPressed = false);
                }
              },
              onHighlightChanged: (pressed) {
                if (_isPressed != pressed) {
                  setState(() => _isPressed = pressed);
                }
              },
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -8,
                    top: -8,
                    right: -8,
                    bottom: -8,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isPressed ? pressedColor : Colors.transparent,
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: MechanixCheckbox(
                      value: widget.isChecked,
                      showFocusIndicator: false,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      checkColor: colorScheme.onPrimary,
                      fillColor: WidgetStateProperty.resolveWith<Color>((
                        Set<WidgetState> states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return colorScheme.primary;
                        }
                        return Colors.transparent;
                      }),
                      side: WidgetStateBorderSide.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return const BorderSide(
                            color: Colors.transparent,
                            width: 0,
                          );
                        }
                        return BorderSide(
                          color: colorScheme.onSurfaceVariant,
                          width: 2,
                        );
                      }),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                      ),
                      onChanged: (_) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
