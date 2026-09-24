import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_button.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/quill_controller_provider.dart';

class TextStyleToolbar extends StatelessWidget {
  const TextStyleToolbar({super.key});

  void _toggle(
    QuillController controller,
    FocusNode focusNode,
    Attribute attribute,
  ) {
    final attrs = controller.getSelectionStyle().attributes;
    final currentAttr = attrs[attribute.key];

    if (currentAttr != null && currentAttr.value == attribute.value) {
      controller.formatSelection(Attribute.clone(attribute, null));
    } else {
      if (attribute.key == Attribute.header.key) {
        controller.formatSelection(Attribute.clone(Attribute.size, null));
      }
      controller.formatSelection(attribute);
    }
    focusNode.requestFocus();
  }

  void _clearHeader(QuillController controller, FocusNode focusNode) {
    controller.formatSelection(Attribute.clone(Attribute.header, null));
    controller.formatSelection(Attribute.clone(Attribute.size, null));
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final provider = QuillControllerProvider.of(context);
    final controller = provider.controller;
    final focusNode = provider.focusNode;

    return Container(
      height: 48,
      decoration: const BoxDecoration(
        // color: NotesColors.searchBarColor,
        boxShadow: [
          BoxShadow(
            // color: NotesColors.boxShadowColor,
            offset: Offset(0, -4),
            blurRadius: 4,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final selectionStyle = controller.getSelectionStyle();
          final attrs = selectionStyle.attributes;

          bool isActive(Attribute attribute) {
            final current = attrs[attribute.key];
            return current != null && current.value == attribute.value;
          }

          bool isParagraph() {
            return !attrs.containsKey(Attribute.header.key) &&
                !attrs.containsKey(Attribute.size.key);
          }

          bool isHeaderActive(int level) {
            return attrs[Attribute.header.key]?.value == level;
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              EditorButton(
                asset: NotesIcon.boldIcon,
                size: 24,
                isActive: isActive(Attribute.bold),
                onPress: () => _toggle(controller, focusNode, Attribute.bold),
              ),
              EditorButton(
                asset: NotesIcon.italicIcon,
                size: 24,
                isActive: isActive(Attribute.italic),
                onPress: () => _toggle(controller, focusNode, Attribute.italic),
              ),
              EditorButton(
                asset: NotesIcon.underlineIcon,
                size: 24,
                isActive: isActive(Attribute.underline),
                onPress: () =>
                    _toggle(controller, focusNode, Attribute.underline),
              ),
              EditorButton(
                asset: NotesIcon.codeBlockIcon,
                size: 24,
                isActive: isActive(Attribute.codeBlock),
                onPress: () =>
                    _toggle(controller, focusNode, Attribute.codeBlock),
              ),
              EditorButton(
                asset: NotesIcon.h1Icon,
                size: 28,
                isActive: isHeaderActive(1),
                onPress: () => _toggle(controller, focusNode, Attribute.h1),
              ),
              EditorButton(
                asset: NotesIcon.h2Icon,
                size: 18,
                isActive: isHeaderActive(2),
                onPress: () => _toggle(controller, focusNode, Attribute.h2),
              ),
              EditorButton(
                asset: NotesIcon.paragraphIcon,
                size: 18,
                isActive: isParagraph(),
                onPress: () => _clearHeader(controller, focusNode),
              ),
            ],
          );
        },
      ),
    );
  }
}
