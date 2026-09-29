import 'package:flutter/material.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_bottom_bar.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_notes_view.dart';
import 'package:widgets/widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surfaceContainerLowest,
      appBar: const MechanixAppBar.large(title: Text("Notes")),
      floatingActionButton: MechanixFloatingActionButton(
        icon: const Icon(Icons.add),
        onPressed: () {
          Navigator.pushNamed(context, '/note-editor');
        },
      ),
      floatingActionButtonLocation: const _CustomFloatingActionButtonLocation(
        offsetFromRight: 24,
        offsetFromBottom: 44,
      ),
      bottomNavigationBar: const HomeBottomBar(),
      body: const HomeNotesView(),
    );
  }
}

class _CustomFloatingActionButtonLocation extends FloatingActionButtonLocation {
  const _CustomFloatingActionButtonLocation({
    this.offsetFromRight = 24.0,
    this.offsetFromBottom = 44.0,
  });

  final double offsetFromRight;
  final double offsetFromBottom;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double x =
        scaffoldGeometry.scaffoldSize.width -
        scaffoldGeometry.floatingActionButtonSize.width -
        offsetFromRight;
    final double y =
        scaffoldGeometry.scaffoldSize.height -
        scaffoldGeometry.floatingActionButtonSize.height -
        offsetFromBottom;
    return Offset(x, y);
  }
}
