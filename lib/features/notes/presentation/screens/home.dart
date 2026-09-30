import 'package:flutter/material.dart';
import 'package:mechanix_notes/core/utils/app_routes.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_bottom_bar.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_notes_view.dart';
import 'package:widgets/widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surfaceContainerLowest,
      appBar: MechanixAppBar.largeIcon(
        title: const Text("Notes"),
        backgroundColor: context.colorScheme.surfaceContainerLowest,
        actions: [
          MechanixIconButton.standard(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.search);
            },
          ),
        ],
      ),
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
