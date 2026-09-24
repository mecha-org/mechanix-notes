import 'package:flutter/material.dart';
import 'package:mechanix_notes/core/utils/icons.dart';

class HomeCardIcon extends StatelessWidget {
  const HomeCardIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        // color: NotesColors.borderColor,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Image.asset(NotesIcon.editIcon, width: 16, height: 16),
    );
  }
}
