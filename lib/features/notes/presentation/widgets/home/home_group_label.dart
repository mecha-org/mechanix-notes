import 'package:flutter/material.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/core/utils/helper.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/time_group.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_note_card.dart';
import 'package:widgets/widgets.dart';

class HomeGroupHeader extends StatelessWidget {
  const HomeGroupHeader({
    super.key,
    required this.group,
    this.count,
    this.isFirst = false,
  });

  final TimeGroup group;
  final int? count;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final title = getLocalizedLabelForTimeNotes(context, group);
    final isRecent = group.category == TimeCategory.recent;
    final countVal = count ?? 0;
    final countStr = countVal.toString().padLeft(2, '0');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MechanixDivider(space: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(title),
            if (!isRecent && countVal > 0) ...[
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
  }
}

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeGroupHeader(group: group, count: notes.length, isFirst: isFirst),
        for (final note in notes)
          HomeNoteCard(key: ValueKey(note.id), note: note),
      ],
    );
  }
}
