import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/bottom_bar/notes_text_link_control.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/quill_controller_provider.dart';
import 'package:widgets/widgets.dart';

class EditorBottomBar extends StatelessWidget {
  const EditorBottomBar({super.key});

  void _handleLinkAction(BuildContext context) {
    // Stub for future link insertion or editing dialog.
  }

  @override
  Widget build(BuildContext context) {
    final provider = QuillControllerProvider.maybeOf(context);

    Widget content;
    if (provider == null) {
      content = NotesTextLinkControl(
        onLinkContextualPressed: () => _handleLinkAction(context),
      );
    } else {
      final controller = provider.controller;
      final focusNode = provider.focusNode;

      content = ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final selectionStyle = controller.getSelectionStyle();
          final toggledStyle = controller.toggledStyle;
          final attrs = selectionStyle.attributes;
          final toggledAttrs = toggledStyle.attributes;

          Attribute? getBlockAttribute(String key) {
            if (toggledAttrs.containsKey(key)) {
              return toggledAttrs[key];
            }
            if (attrs.containsKey(key)) {
              return attrs[key];
            }
            final sel = controller.selection;
            if (sel.isValid &&
                sel.start >= 0 &&
                sel.start <= controller.document.length) {
              final child = controller.document.queryChild(sel.start);
              final node = child.node;
              if (node is Line) {
                if (node.style.containsKey(key)) {
                  return node.style.attributes[key];
                }
                if (node.parent is Block) {
                  return (node.parent as Block).style.attributes[key];
                }
              }
            }
            return null;
          }

          bool isAttrActive(Attribute attribute) {
            if (toggledAttrs.containsKey(attribute.key)) {
              return toggledAttrs[attribute.key]?.value == attribute.value;
            }
            final current = attrs[attribute.key];
            return current != null && current.value == attribute.value;
          }

          bool isHeaderActive(int level) {
            return getBlockAttribute(Attribute.header.key)?.value == level;
          }

          bool isParagraphActive() {
            return getBlockAttribute(Attribute.header.key) == null &&
                !attrs.containsKey(Attribute.size.key) &&
                getBlockAttribute(Attribute.list.key) == null;
          }

          void toggleInline(Attribute attribute) {
            if (isAttrActive(attribute)) {
              controller.formatSelection(Attribute.clone(attribute, null));
            } else {
              controller.formatSelection(attribute);
            }
            focusNode.requestFocus();
          }

          void toggleHeader(int level) {
            final currentLevel = getBlockAttribute(Attribute.header.key)?.value;
            if (currentLevel == level) {
              controller.formatSelection(
                Attribute.clone(Attribute.header, null),
              );
            } else {
              controller.formatSelection(Attribute.clone(Attribute.size, null));
              controller.formatSelection(
                Attribute.fromKeyValue(Attribute.header.key, level),
              );
            }
            focusNode.requestFocus();
          }

          void clearToParagraph() {
            controller.formatSelection(Attribute.clone(Attribute.header, null));
            controller.formatSelection(Attribute.clone(Attribute.size, null));
            controller.formatSelection(Attribute.clone(Attribute.list, null));
            focusNode.requestFocus();
          }

          void toggleChecklist() {
            final currentList = getBlockAttribute(Attribute.list.key)?.value;
            if (currentList == Attribute.unchecked.value ||
                currentList == Attribute.checked.value) {
              controller.formatSelection(Attribute.clone(Attribute.list, null));
            } else {
              controller.formatSelection(Attribute.unchecked);
            }
            focusNode.requestFocus();
          }

          void toggleCodeBlock() {
            final isCode = isAttrActive(Attribute.codeBlock);
            if (isCode) {
              controller.formatSelection(
                Attribute.clone(Attribute.codeBlock, null),
              );
            } else {
              controller.formatSelection(Attribute.codeBlock);
            }
            focusNode.requestFocus();
          }

          final listAttr = getBlockAttribute(Attribute.list.key);
          final isChecklistActive =
              listAttr?.value == Attribute.unchecked.value ||
              listAttr?.value == Attribute.checked.value;

          return NotesTextLinkControl(
            isTextContextualActive: isHeaderActive(1),
            onTextContextualPressed: () => toggleHeader(1),
            isH2Active: isHeaderActive(2),
            onH2Pressed: () => toggleHeader(2),
            isBodyActive: isParagraphActive(),
            onBodyPressed: clearToParagraph,
            isBoldActive: isAttrActive(Attribute.bold),
            onBoldPressed: () => toggleInline(Attribute.bold),
            isItalicActive: isAttrActive(Attribute.italic),
            onItalicPressed: () => toggleInline(Attribute.italic),
            isUnderlineActive: isAttrActive(Attribute.underline),
            onUnderlinePressed: () => toggleInline(Attribute.underline),
            isStrikethroughActive: isAttrActive(Attribute.strikeThrough),
            onStrikethroughPressed: () => toggleInline(Attribute.strikeThrough),
            isChecklistActive: isChecklistActive,
            onChecklistPressed: toggleChecklist,
            isCodeActive: isAttrActive(Attribute.codeBlock),
            onCodePressed: toggleCodeBlock,
            onLinkContextualPressed: () => _handleLinkAction(context),
          );
        },
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: content,
    );
  }
}
