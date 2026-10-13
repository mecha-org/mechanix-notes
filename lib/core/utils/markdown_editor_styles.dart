import 'package:flutter/material.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart';
import 'package:widgets/widgets.dart';

MarkdownEditorThemeData markdownEditorTheme(BuildContext context) {
  final colorScheme = context.colorScheme;
  final textTheme = Theme.of(context).textTheme;
  final bodyLarge = textTheme.emphasized.bodyLarge ?? const TextStyle();
  final headlineLarge = textTheme.emphasized.headlineLarge ?? const TextStyle();
  final headlineSmall = textTheme.emphasized.headlineSmall ?? const TextStyle();
  final titleLarge = textTheme.titleLarge ?? const TextStyle();
  final titleMedium = textTheme.titleMedium ?? const TextStyle();
  final titleSmall = textTheme.titleSmall ?? const TextStyle();
  final bodyMedium = textTheme.bodyMedium ?? const TextStyle();

  final codeTextStyle = TextStyle(
    fontFamily: MechanixFontFamily.geistMono,
    package: mechanixFontPackage,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 23 / 18,
    letterSpacing: 0,
    color: colorScheme.onSurface,
  );

  return MarkdownEditorThemeData(
    backgroundColor: colorScheme.surfaceContainerLowest,
    textColor: colorScheme.onSurface,
    mutedTextColor: colorScheme.onSurfaceVariant,
    accentColor: colorScheme.primary,
    selectionColor: colorScheme.primary.withValues(alpha: 0.28),
    caretColor: colorScheme.primary,
    highlightColor: colorScheme.primary.withValues(alpha: 0.15),
    codeBackgroundColor: colorScheme.surfaceContainer,
    quoteBorderColor: colorScheme.outlineVariant,
    taskBorderColor: colorScheme.onSurfaceVariant,
    taskCheckedColor: colorScheme.primary,
    bodyStyle: bodyLarge.copyWith(color: colorScheme.onSurface),
    codeStyle: codeTextStyle,
    headingStyles: [
      headlineLarge.copyWith(color: colorScheme.onSurface), // H1
      headlineSmall.copyWith(color: colorScheme.onSurface), // H2
      titleLarge.copyWith(color: colorScheme.onSurface), // H3
      titleMedium.copyWith(color: colorScheme.onSurface), // H4
      titleSmall.copyWith(color: colorScheme.onSurface), // H5
      bodyMedium.copyWith(color: colorScheme.onSurface), // H6
    ],
    contentPadding: const EdgeInsets.all(24),
    maxContentWidth: 4000.0,
    taskSize: 18,
  );
}
