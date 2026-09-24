import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_state.dart';

class HomeFloatingBar extends StatelessWidget {
  const HomeFloatingBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotesBloc, NotesState>(
      buildWhen: (prev, curr) => prev.isSelectionMode != curr.isSelectionMode,
      builder: (context, state) {
        if (state.isSelectionMode) return const SizedBox.shrink();

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            BlocSelector<NotesBloc, NotesState, bool>(
              selector: (state) => state.notes.isNotEmpty,
              builder: (context, hasNotes) {
                return FloatingActionButton.small(
                  mouseCursor: SystemMouseCursors.click,
                  heroTag: 'search',
                  onPressed: hasNotes
                      ? () {
                          Navigator.pushNamed(context, '/search');
                        }
                      : null,
                  // backgroundColor: NotesColors.bottomBarBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: const BorderSide(
                      // color: NotesColors.borderColor,
                      width: 0.5,
                    ),
                  ),
                  child: Image.asset(
                    NotesIcon.searchIcon,
                    width: 20,
                    height: 20,
                    color: hasNotes ? Colors.white : Colors.white30,
                  ),
                );
              },
            ),

            const SizedBox(height: 12),
            FloatingActionButton(
              mouseCursor: SystemMouseCursors.click,
              heroTag: 'create',
              onPressed: () {
                Navigator.pushNamed(context, '/note-editor');
              },
              // backgroundColor: NotesColors.borderColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              child: Image.asset(
                NotesIcon.createIcon,
                width: 28,
                height: 28,
                color: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
}
