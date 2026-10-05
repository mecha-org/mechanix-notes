import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_notes/core/utils/app_routes.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_state.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/card/home_note_card_content.dart';

class HomeNoteCard extends StatelessWidget {
  final NoteMetaData note;

  const HomeNoteCard({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotesBloc, NotesState>(
      buildWhen: (previous, current) {
        final wasSelected = previous.selectedNotes.contains(note.id);
        final isSelected = current.selectedNotes.contains(note.id);
        return wasSelected != isSelected ||
            previous.isSelectionMode != current.isSelectionMode;
      },
      builder: (context, state) {
        final isSelectionMode = state.isSelectionMode;
        final isSelected = state.selectedNotes.contains(note.id);

        return HomeNoteCardContent(
          note: note,
          isSelectionMode: isSelectionMode,
          isSelected: isSelected,
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.noteEditor,
            arguments: {'noteId': note.id, 'noteTitle': note.title},
          ),
        );
      },
    );
  }
}
