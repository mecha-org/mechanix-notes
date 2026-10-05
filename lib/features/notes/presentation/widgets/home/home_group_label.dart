import 'package:flutter/material.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/core/utils/helper.dart';
import 'package:mechanix_notes/features/notes/data/models/time_group.dart';
import 'package:widgets/widgets.dart';

class HomeGroupHeader extends StatelessWidget {
  const HomeGroupHeader({
    super.key,
    required this.group,
    this.count,
    this.isFirst = false,
    this.children = const <Widget>[],
  });

  final TimeGroup group;
  final int? count;
  final bool isFirst;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final title = getLocalizedLabelForTimeNotes(context, group);
    final isRecent = group.category == TimeCategory.recent;
    final countVal = count ?? children.length;
    final countStr = countVal.toString().padLeft(2, '0');

    return MechanixExpandableListTile(
      key: ValueKey('tile_${group.category}_${group.customLabel}'),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          if (!isRecent && countVal > 0) ...[
            const SizedBox(width: 4),
            Transform.translate(
              offset: const Offset(0, -4),
              child: Text(
                '[$countStr]',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
      showAccordionButton: false,
      backgroundColor: context.colorScheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 24.0,
        vertical: 4.0,
      ),
      initiallyExpanded: true,
      childrenPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8.0,
      ),
      children: children,
    );
  }
}
