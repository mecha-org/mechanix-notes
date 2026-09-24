import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

DefaultStyles quillEditorStyle(BuildContext context) {
  return const DefaultStyles(
    bold: TextStyle(fontWeight: FontWeight.w700),
    italic: TextStyle(fontStyle: FontStyle.italic),
    underline: TextStyle(decoration: TextDecoration.underline),
    paragraph: DefaultTextBlockStyle(
      TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        fontFamily: "Sora",
        color: Colors.white,
        height: 1.45,
        letterSpacing: 0.0,
      ),
      HorizontalSpacing(0, 0),
      VerticalSpacing(0, 0),
      VerticalSpacing(0, 0),
      null,
    ),

    h1: DefaultTextBlockStyle(
      TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        height: 1.3,
        fontFamily: "Sora",
        letterSpacing: 0,
      ),
      HorizontalSpacing(0, 0),
      VerticalSpacing(10, 10),
      VerticalSpacing(0, 0),
      null,
    ),

    h2: DefaultTextBlockStyle(
      TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        fontFamily: "Sora",
        height: 1.25,
        letterSpacing: 0,
      ),
      HorizontalSpacing(0, 0),
      VerticalSpacing(5, 5),
      VerticalSpacing(0, 0),
      null,
    ),

    h3: DefaultTextBlockStyle(
      TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFamily: "Sora",
        color: Colors.white,
        height: 1.2,
        letterSpacing: 0.2,
      ),
      HorizontalSpacing(0, 0),
      VerticalSpacing(2, 2),
      VerticalSpacing(0, 0),
      null,
    ),

    placeHolder: DefaultTextBlockStyle(
      TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        fontFamily: "Sora",
        color: Colors.white30,
        height: 1.2,
        letterSpacing: 0.2,
      ),
      HorizontalSpacing(0, 0),
      VerticalSpacing(14, 8),
      VerticalSpacing(0, 0),
      null,
    ),
    quote: DefaultTextBlockStyle(
      TextStyle(
        fontSize: 18,
        color: Colors.white,
        height: 1.2,
        fontFamily: "Sora",
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
      TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: Colors.white,
        height: 1.35,
        letterSpacing: -0.4,
        fontFamily: "Sora",
      ),
      HorizontalSpacing(0, 0),
      VerticalSpacing(16, 16),
      VerticalSpacing(0, 0),

      BoxDecoration(
        // color: NotesColors.bottomBarBg,
        borderRadius: BorderRadius.all(Radius.circular(0)),
      ),
    ),

    lists: DefaultListBlockStyle(
      TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w400,
        fontFamily: "Sora",
        height: 1.35,
      ),
      HorizontalSpacing(0, 0),
      VerticalSpacing(0, 0),
      VerticalSpacing(0, 0),
      null,
      null,
    ),

    link: TextStyle(
      // color: NotesColors.linkColor,
      decoration: TextDecoration.underline,
      // decorationColor: NotesColors.linkColor,
      fontFamily: "Sora",
    ),
    color: Colors.white,
  );
}
