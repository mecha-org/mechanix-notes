import 'package:flutter/material.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/quill_controller_provider.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/topbar/editor_undo_redo_actions.dart';
import 'package:widgets/widgets.dart';

class EditorTopBar extends StatelessWidget implements PreferredSizeWidget {
  const EditorTopBar({super.key});

  @override
  Size get preferredSize => const MechanixAppBar().preferredSize;

  @override
  Widget build(BuildContext context) {
    final quillController = QuillControllerProvider.maybeOf(
      context,
    )?.controller;

    return MechanixAppBar(
      leading: MechanixIconButton.standard(
        type: IconButtonType.rounded,
        onPressed: () => Navigator.maybePop(context),
        foregroundColor: context.colorScheme.onSurface,
        icon: const ImageIcon(AssetImage(NotesIcon.backIcon)),
      ),
      actions: [
        EditorUndoRedoActions(quillController: quillController),
        MechanixIconButton.standard(
          type: IconButtonType.rounded,
          onPressed: () => Navigator.maybePop(context),
          foregroundColor: context.colorScheme.onSurface,
          icon: const ImageIcon(AssetImage(NotesIcon.moreVertIcon)),
        ),
      ],
    );
  }
}
