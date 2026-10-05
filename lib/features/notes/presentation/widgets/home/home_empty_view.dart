import 'package:flutter/material.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';
import 'package:widgets/widgets.dart';

class HomeEmptyView extends StatelessWidget {
  const HomeEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Text(
        AppLocalizations.of(context)!.writeANote,
        style: context.textTheme.titleLarge?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
