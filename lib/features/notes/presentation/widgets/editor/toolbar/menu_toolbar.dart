import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_button.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/quill_controller_provider.dart';

class MenuToolbar extends StatelessWidget {
  const MenuToolbar({super.key});

  void _toggleList(
    QuillController controller,
    FocusNode focusNode,
    Attribute attribute,
  ) {
    final selection = controller.selection;
    final attrs = controller.getSelectionStyle().attributes;
    final currentAttr = attrs[attribute.key];

    if (currentAttr != null && currentAttr.value == attribute.value) {
      controller.formatSelection(Attribute.clone(attribute, null));
    } else {
      controller.formatSelection(attribute);
    }
    controller.updateSelection(selection, ChangeSource.local);
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final provider = QuillControllerProvider.of(context);
    final controller = provider.controller;
    final focusNode = provider.focusNode;

    return Container(
      height: 48,
      alignment: Alignment.center,
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

          bool isActive(Attribute attribute) {
            final attrs = selectionStyle.attributes;
            final current = attrs[attribute.key];
            return current != null && current.value == attribute.value;
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              EditorButton(
                asset: NotesIcon.todoIcon,
                size: 28,
                isActive: isActive(Attribute.unchecked),
                onPress: () =>
                    _toggleList(controller, focusNode, Attribute.unchecked),
              ),
              const SizedBox(width: 40),
              EditorButton(
                asset: NotesIcon.listIcon,
                size: 28,
                isActive: isActive(Attribute.ul),
                onPress: () => _toggleList(controller, focusNode, Attribute.ul),
              ),
            ],
          );
        },
      ),
    );
  }
}
