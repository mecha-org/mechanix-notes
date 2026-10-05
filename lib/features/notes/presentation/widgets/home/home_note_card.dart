import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mechanix_notes/core/utils/app_routes.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:widgets/widgets.dart';

class HomeNoteCard extends StatelessWidget {
  final NoteMetaData note;
  final VoidCallback? onTap;

  const HomeNoteCard({super.key, required this.note, this.onTap});

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
    if (note.isPinned) {
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
      showLeading: note.isPinned,
      labelColor: context.colorScheme.onSurface,
      supportingTextColor: context.colorScheme.onSurfaceVariant,
      onTap:
          onTap ??
          () => Navigator.pushNamed(
            context,
            AppRoutes.noteEditor,
            arguments: {'noteId': note.id, 'noteTitle': note.title},
          ),
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
