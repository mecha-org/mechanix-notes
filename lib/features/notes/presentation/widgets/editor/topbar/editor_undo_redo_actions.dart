import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:widgets/widgets.dart';

class EditorUndoRedoActions extends StatelessWidget {
  const EditorUndoRedoActions({super.key, this.quillController});

  final QuillController? quillController;

  @override
  Widget build(BuildContext context) {
    if (quillController == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MechanixIconButton.standard(
            type: IconButtonType.rounded,
            onPressed: null,
            foregroundColor: context.colorScheme.onSurface,
            icon: const ImageIcon(AssetImage(NotesIcon.undoIcon)),
          ),
          MechanixIconButton.standard(
            type: IconButtonType.rounded,
            onPressed: null,
            foregroundColor: context.colorScheme.onSurface,
            icon: const ImageIcon(AssetImage(NotesIcon.redoIcon)),
          ),
        ],
      );
    }

    return ListenableBuilder(
      listenable: quillController!,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MechanixIconButton.standard(
            type: IconButtonType.rounded,
            onPressed: quillController!.hasUndo ? quillController!.undo : null,
            foregroundColor: context.colorScheme.onSurface,
            icon: const ImageIcon(AssetImage(NotesIcon.undoIcon)),
          ),
          MechanixIconButton.standard(
            type: IconButtonType.rounded,
            onPressed: quillController!.hasRedo ? quillController!.redo : null,
            foregroundColor: context.colorScheme.onSurface,
            icon: const ImageIcon(AssetImage(NotesIcon.redoIcon)),
          ),
        ],
      ),
    );
  }
}
