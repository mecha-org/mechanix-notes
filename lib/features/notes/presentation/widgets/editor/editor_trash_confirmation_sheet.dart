import 'package:flutter/material.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:widgets/widgets.dart';

class EditorTrashConfirmationSheet extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const EditorTrashConfirmationSheet({
    super.key,
    required this.onCancel,
    required this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
  }) {
    return MechanixBottomSheet.showModal(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => EditorTrashConfirmationSheet(
        onCancel: () {
          Navigator.of(sheetContext).pop();
          onCancel?.call();
        },
        onConfirm: () {
          Navigator.of(sheetContext).pop();
          onConfirm();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Do you want to move this note to trash?',
              style: context.textTheme.titleMedium?.copyWith(
                color: context.colorScheme.onSurface,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                spacing: 16,
                children: [
                  Expanded(
                    child: MechanixButton.outline(
                      widthSizing: ButtonLayoutSizing.fill,
                      size: ButtonSize.large,
                      label: 'CANCEL',
                      icon: const ImageIcon(
                        AssetImage(NotesIcon.closeIcon),
                        size: 24,
                      ),
                      onPressed: onCancel,
                    ),
                  ),
                  Expanded(
                    child: MechanixFilledButton(
                      widthSizing: ButtonLayoutSizing.fill,
                      size: ButtonSize.large,
                      label: 'TRASH',
                      backgroundColor:
                          context.colorScheme.surfaceContainerHighest,
                      foregroundColor: context.colorScheme.error,
                      icon: ImageIcon(
                        const AssetImage(NotesIcon.trashIcon),
                        size: 24,
                        color: context.colorScheme.error,
                      ),
                      onPressed: onConfirm,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
