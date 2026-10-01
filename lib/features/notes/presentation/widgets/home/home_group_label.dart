import 'package:flutter/material.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/core/utils/helper.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/time_group.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_note_card.dart';
import 'package:widgets/widgets.dart';

class HomeGroupAccordion extends StatelessWidget {
  const HomeGroupAccordion({
    super.key,
    required this.group,
    required this.notes,
    this.isFirst = false,
  });

  final TimeGroup group;
  final List<NoteMetaData> notes;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final title = getLocalizedLabelForTimeNotes(context, group);
    final isRecent = group.category == TimeCategory.recent;
    final count = notes.length;
    final countStr = count.toString().padLeft(2, '0');

    final labelWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MechanixDivider(space: 12),

        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(title),
            if (!isRecent && count > 0) ...[
              const SizedBox(width: 8),
              Text(
                '[$countStr]',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        const MechanixDivider(space: 12),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MechanixExpandableListTile(
          key: ValueKey('accordion_${group.category}_${group.customLabel}'),
          showAccordionButton: false,
          initiallyExpanded: true,
          expandedBackgroundColor: context.colorScheme.surfaceContainerLowest,
          variant: ListTileVariant.standard,
          label: labelWidget,
          children: [
            for (final note in notes)
              HomeNoteCard(key: ValueKey(note.id), note: note),
          ],
        ),
      ],
    );
  }
}

/// Legacy header retained for compatibility.
class HomeGroupHeader extends StatelessWidget {
  const HomeGroupHeader({super.key, required this.group});

  final TimeGroup group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 26.0),
          child: Text(
            getLocalizedLabelForTimeNotes(context, group),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
