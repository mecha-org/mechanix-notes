import 'package:flutter/material.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_button.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';

class HomeDeleteSheet extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onDelete;
  const HomeDeleteSheet({
    super.key,
    required this.selectedCount,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        // color: NotesColors.searchBarColor,
        border: Border(
          // top: BorderSide(color: NotesColors.borderColor, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.topRight,
                  child: EditorButton(
                    onPress: () => Navigator.of(context).pop(),
                    size: 24,
                    asset: NotesIcon.closeIcon,
                  ),
                ),
              ),

              // const Divider(color: NotesColors.borderColor),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    Text(
                      AppLocalizations.of(
                        context,
                      )!.deleteNotePromptTitle(selectedCount),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      AppLocalizations.of(
                        context,
                      )!.deleteNotePromptSubtitle(selectedCount),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),

                    const SizedBox(height: 28),

                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: FilledButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: FilledButton.styleFrom(
                                enabledMouseCursor: SystemMouseCursors.click,
                                // backgroundColor:
                                //     NotesColors.backgroundFilledColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(0),
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.cancel,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: FilledButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                onDelete();
                              },
                              style: FilledButton.styleFrom(
                                enabledMouseCursor: SystemMouseCursors.click,
                                // backgroundColor: NotesColors.deleteButtonColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(0),
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.delete,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
