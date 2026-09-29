import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_event.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_state.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/time_group.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_group_label.dart';

class HomeListView extends StatefulWidget {
  const HomeListView({super.key, required this.groupedNotes});

  final List<dynamic> groupedNotes;

  @override
  State<HomeListView> createState() => _HomeListViewState();
}

class _HomeListViewState extends State<HomeListView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    // Trigger when within 200 px of the bottom
    if (position.pixels >= position.maxScrollExtent - 200) {
      final state = context.read<NotesBloc>().state;
      if (!state.isLoadingMore && state.hasMore) {
        context.read<NotesBloc>().add(LoadMoreNotes());
      }
    }
  }

  List<_NoteSectionData> _buildSections(List<dynamic> items) {
    final sections = <_NoteSectionData>[];
    TimeGroup? currentGroup;
    List<NoteMetaData> currentNotes = [];

    for (final item in items) {
      if (item is TimeGroup) {
        if (currentGroup != null) {
          sections.add(
            _NoteSectionData(group: currentGroup, notes: currentNotes),
          );
        }
        currentGroup = item;
        currentNotes = [];
      } else if (item is NoteMetaData) {
        currentGroup ??= const TimeGroup(TimeCategory.recent);
        currentNotes.add(item);
      }
    }

    if (currentGroup != null) {
      sections.add(
        _NoteSectionData(group: currentGroup, notes: currentNotes),
      );
    }

    return sections;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NotesBloc, NotesState>(
      listenWhen: (prev, curr) => curr.isRefreshed,
      listener: (context, state) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: BlocBuilder<NotesBloc, NotesState>(
        buildWhen: (prev, curr) => prev.groupedNotes != curr.groupedNotes,
        builder: (context, state) {
          final sections = _buildSections(state.groupedNotes);

          return Scrollbar(
            controller: _scrollController,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
              ),
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 8.0, bottom: 40.0),
                itemCount: sections.length,
                itemBuilder: (context, index) {
                  final section = sections[index];
                  return HomeGroupAccordion(
                    key: ValueKey(section.group),
                    group: section.group,
                    notes: section.notes,
                    isFirst: index == 0,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NoteSectionData {
  final TimeGroup group;
  final List<NoteMetaData> notes;

  const _NoteSectionData({required this.group, required this.notes});
}
