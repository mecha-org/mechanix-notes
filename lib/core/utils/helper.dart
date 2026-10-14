import 'package:flutter/material.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/features/notes/data/models/time_group.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';

String getLocalizedLabelForTimeNotes(BuildContext context, TimeGroup group) {
  switch (group.category) {
    case TimeCategory.pinned:
      return AppLocalizations.of(context)!.pinned;
    case TimeCategory.recent:
      return AppLocalizations.of(context)!.recent;
    case TimeCategory.today:
      return AppLocalizations.of(context)!.today;
    case TimeCategory.yesterday:
      return AppLocalizations.of(context)!.yesterday;
    case TimeCategory.last7Days:
      return AppLocalizations.of(context)!.last7Days;
    case TimeCategory.thisWeek:
      return AppLocalizations.of(context)!.thisWeek;
    case TimeCategory.lastWeek:
      return AppLocalizations.of(context)!.lastWeek;
    case TimeCategory.thisMonth:
      return AppLocalizations.of(context)!.thisMonth;
    case TimeCategory.lastMonth:
      return AppLocalizations.of(context)!.lastMonth;
    case TimeCategory.custom:
      return group.customLabel ?? '';
  }
}

String localizeError(BuildContext context, ErrorCategory error) {
  switch (error) {
    case ErrorCategory.noteNotFound:
      return AppLocalizations.of(context)!.noteNotFound;
    case ErrorCategory.somethingWentWrong:
      return AppLocalizations.of(context)!.somethingWentWrong;
    case ErrorCategory.failedToSaveNote:
      return AppLocalizations.of(context)!.failedToSaveNote;
    case ErrorCategory.storageFull:
      return AppLocalizations.of(context)!.storageFull;
    case ErrorCategory.failedToLoadNotes:
      return AppLocalizations.of(context)!.failedToLoadNotes;
    case ErrorCategory.failedToDeleteNotes:
      return AppLocalizations.of(context)!.failedToDeleteNotes;
    case ErrorCategory.appAlreadyRunning:
      return AppLocalizations.of(context)!.appAlreadyRunning;
    case ErrorCategory.unknown:
      return AppLocalizations.of(context)!.somethingWentWrong;
  }
}

/// Strips common Markdown formatting tokens to produce clean plain text
/// suitable for search indexing (Tantivy) and preview text.
String markdownToPlainText(String markdown) {
  if (markdown.isEmpty) return '';

  var text = markdown;
  // Remove HTML comments (including mechanix:id tags)
  text = text.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  // Remove fenced code blocks completely or keep inner text
  text = text.replaceAll(RegExp(r'```[^\n]*\n([\s\S]*?)\n```'), r'$1');
  // Remove task list markers `- [ ] ` and `- [x] `
  text = text.replaceAll(
    RegExp(r'^\s*[-+*]\s+\[[ xX]\]\s+', multiLine: true),
    '',
  );
  // Remove unordered list markers `* `, `- `, `+ `
  text = text.replaceAll(RegExp(r'^\s*[-+*]\s+', multiLine: true), '');
  // Remove ordered list markers `1. `
  text = text.replaceAll(RegExp(r'^\s*\d+[.)]\s+', multiLine: true), '');
  // Remove blockquote markers `> `
  text = text.replaceAll(RegExp(r'^\s*>\s*', multiLine: true), '');
  // Remove headers `# `, `## `, etc.
  text = text.replaceAll(RegExp(r'^\s*#{1,6}\s+', multiLine: true), '');
  // Remove images `![alt](url)` -> `alt`
  text = text.replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), r'$1');
  // Remove links `[text](url)` -> `text`
  text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]*\)'), r'$1');
  // Remove bold/italic `**text**` or `__text__`
  text = text.replaceAll(RegExp(r'(\*\*|__)(.*?)\1'), r'$2');
  // Remove single `*text*` or `_text_`
  text = text.replaceAll(RegExp(r'(\*|_)(.*?)\1'), r'$2');
  // Remove strikethrough `~~text~~`
  text = text.replaceAll(RegExp(r'~~(.*?)~~'), r'$1');
  // Remove highlight `==text==`
  text = text.replaceAll(RegExp(r'==(.*?)=='), r'$1');
  // Remove inline code
  text = text.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
  // Remove horizontal rules
  text = text.replaceAll(RegExp(r'^\s*([-*_]){3,}\s*$', multiLine: true), '');

  return text;
}

/// Estimates card height for the staggered grid layout based on text length.
double estimateNoteHeight(String plainText) {
  const lineHeight = 24.0;
  const charsPerLine = 60;
  final lines = (plainText.length / charsPerLine).ceil().clamp(1, 20);
  return lines * lineHeight + 80;
}
