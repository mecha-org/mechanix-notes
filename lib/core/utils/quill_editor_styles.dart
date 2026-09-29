import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:widgets/widgets.dart';

DefaultStyles quillEditorStyle(BuildContext context) {
  final bodyLarge =
      Theme.of(context).textTheme.emphasized.bodyLarge ?? const TextStyle();
  final headlineSmall =
      Theme.of(context).textTheme.emphasized.headlineSmall ?? const TextStyle();
  final titleLarge =
      Theme.of(context).textTheme.titleLarge ?? const TextStyle();
  final codeTextStyle = TextStyle(
    fontFamily: MechanixFontFamily.geistMono,
    package: mechanixFontPackage,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 23 / 18, // 23px line-height
    letterSpacing: 0,
    color: context.colorScheme.onSurface, // #F5F5F5
  );

  return DefaultStyles(
    bold: const TextStyle(fontWeight: FontWeight.w700),
    italic: const TextStyle(fontStyle: FontStyle.italic),
    underline: const TextStyle(decoration: TextDecoration.underline),
    strikeThrough: const TextStyle(decoration: TextDecoration.lineThrough),
    paragraph: DefaultTextBlockStyle(
      bodyLarge,
      const HorizontalSpacing(0, 0),
      const VerticalSpacing(0, 0),
      const VerticalSpacing(0, 0),
      null,
    ),

    h1: const DefaultTextBlockStyle(
      TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        height: 1.3,
        letterSpacing: 0,
      ),
      HorizontalSpacing(0, 0),
      VerticalSpacing(10, 10),
      VerticalSpacing(0, 0),
      null,
    ),

    h2: DefaultTextBlockStyle(
      headlineSmall,
      const HorizontalSpacing(0, 0),
      const VerticalSpacing(5, 5),
      const VerticalSpacing(0, 0),
      null,
    ),

    placeHolder: const DefaultTextBlockStyle(
      TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: Colors.white30,
        height: 1.2,
        letterSpacing: 0.2,
      ),
      HorizontalSpacing(0, 0),
      VerticalSpacing(14, 8),
      VerticalSpacing(0, 0),
      null,
    ),
    quote: const DefaultTextBlockStyle(
      TextStyle(
        fontSize: 18,
        color: Colors.white,
        height: 1.2,
        fontStyle: FontStyle.italic,
      ),
      HorizontalSpacing(0, 0),
      VerticalSpacing(8, 8),
      VerticalSpacing(0, 0),
      BoxDecoration(
        border: Border(
          // left: BorderSide(color: NotesColors.appTitleColor, width: 3),
        ),
      ),
    ),

    code: DefaultTextBlockStyle(
      codeTextStyle,
      const HorizontalSpacing(0, 0),
      const VerticalSpacing(20, 20),
      const VerticalSpacing(0, 0),
      BoxDecoration(color: context.colorScheme.surfaceContainer),
    ),

    lists: DefaultListBlockStyle(
      titleLarge,
      const HorizontalSpacing(0, 18),
      const VerticalSpacing(0, 0),
      const VerticalSpacing(9, 9),
      null,
      null,
    ),

    link: const TextStyle(
      // color: NotesColors.linkColor,
      decoration: TextDecoration.underline,
      // decorationColor: NotesColors.linkColor,
    ),
    color: Colors.white,
  );
}
