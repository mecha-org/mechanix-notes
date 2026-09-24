import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_state.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';

class HomeTitleBar extends StatelessWidget {
  const HomeTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 20, top: 16, bottom: 4),
      child: BlocBuilder<NotesBloc, NotesState>(
        buildWhen: (prev, curr) =>
            prev.isSelectionMode != curr.isSelectionMode ||
            prev.selectedNotes.length != curr.selectedNotes.length,
        builder: (context, state) {
          final count = state.selectedNotes.length;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (state.isSelectionMode)
                Text(
                  AppLocalizations.of(context)!.notesSelected(count),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    // color: NotesColors.appTitleColor,
                  ),
                )
              else
                Text(
                  AppLocalizations.of(context)!.notes,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
            ],
          );
        },
      ),
    );
  }
}
