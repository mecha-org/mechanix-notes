import 'package:flutter/material.dart';

class HomeCardSelectionIcon extends StatelessWidget {
  final bool isSelected;
  const HomeCardSelectionIcon({super.key, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(top: 2, right: 12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          // color: isSelected ? NotesColors.titleColor : NotesColors.borderColor,
          width: 2,
        ),
        // color: isSelected ? NotesColors.titleColor : Colors.transparent,
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 16, color: Colors.black)
          : null,
    );
  }
}
