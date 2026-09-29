import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_event.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_state.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_delete_sheet.dart';

class HomeBottomBar extends StatelessWidget {
  const HomeBottomBar({super.key});

  void _showDeleteSheet(BuildContext context, int selectedCount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return HomeDeleteSheet(
          selectedCount: selectedCount,
          onDelete: () {
            context.read<NotesBloc>().add(DeleteNotes());
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotesBloc, NotesState>(
      buildWhen: (previous, current) =>
          previous.isSelectionMode != current.isSelectionMode ||
          previous.selectedNotes.length != current.selectedNotes.length,
      builder: (context, state) {
        if (!state.isSelectionMode) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 60,
          // decoration: const BoxDecoration(color: NotesColors.bottomBarBg),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _BottomBarIcon(
                  iconPath: NotesIcon.closeIcon,
                  color: Colors.white,
                  onPressed: () {
                    context.read<NotesBloc>().add(ClearSelection());
                  },
                ),

                _BottomBarIcon(
                  iconPath: NotesIcon.selectAllIcon,
                  color: Colors.white,
                  onPressed: () {
                    context.read<NotesBloc>().add(SelectAllNotes());
                  },
                ),

                _BottomBarIcon(
                  iconPath: NotesIcon.trashIcon,
                  color: state.selectedNotes.isNotEmpty
                      ? Colors.red
                      : Colors.grey,
                  onPressed: state.selectedNotes.isNotEmpty
                      ? () {
                          _showDeleteSheet(context, state.selectedNotes.length);
                        }
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BottomBarIcon extends StatelessWidget {
  final String iconPath;
  final VoidCallback? onPressed;
  final Color color;

  const _BottomBarIcon({
    required this.iconPath,
    this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: const EdgeInsets.all(10),
      onPressed: onPressed,
      icon: Image.asset(iconPath, width: 24, height: 24, color: color),
    );
  }
}
