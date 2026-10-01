import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/card/home_card_selection_icon.dart';
import 'package:widgets/widgets.dart';

class HomeNoteCardContent extends StatelessWidget {
  final NoteMetaData note;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const HomeNoteCardContent({
    super.key,
    required this.note,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final title = note.title.isNotEmpty ? note.title : note.previewText;
    final supportingText =
        note.title.isNotEmpty &&
            note.previewText.isNotEmpty &&
            note.title != note.previewText
        ? note.previewText
        : null;
    final formattedDate = _formatDate(note.updatedAt);

    final Widget? leading;
    if (isSelectionMode) {
      leading = HomeCardSelectionIcon(isSelected: isSelected);
    } else if (note.isPinned) {
      leading = ImageIcon(
        const AssetImage(NotesIcon.pinIcon),
        size: 16,
        color: context.colorScheme.primary,
      );
    } else {
      leading = null;
    }

    return MechanixListTile(
      variant: ListTileVariant.standard,
      labelText: title,
      supportingText: supportingText,
      trailingText: formattedDate,
      leading: leading,
      showLeading: isSelectionMode || note.isPinned,
      selected: isSelected,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 24.0,
        vertical: 8.0,
      ),
      labelColor: context.colorScheme.onSurface,
      supportingTextColor: context.colorScheme.onSurfaceVariant,
      onTap: onTap,
      onLongPress: isSelectionMode ? null : onLongPress,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (now.year != date.year) {
      return DateFormat('dd MMM yy').format(date).toUpperCase();
    }
    return DateFormat('dd MMM').format(date).toUpperCase();
  }
}
