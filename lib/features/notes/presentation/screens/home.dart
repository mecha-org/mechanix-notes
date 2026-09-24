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
      // floatingActionButton: MechanixFloatingActionButton(
      //   icon: const Icon(Icons.add),
      //   onPressed: () {
      //     Navigator.pushNamed(context, '/note-editor');
      //   },
      // ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.pushNamed(context, '/note-editor');
        },
      ),
      bottomNavigationBar: const HomeBottomBar(),
      body: const HomeNotesView(),
    );
  }
}
