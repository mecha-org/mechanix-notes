import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_event.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_state.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/time_group.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_group_label.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_note_card.dart';

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

  Map<TimeGroup, int> _countNotesPerGroup(List<dynamic> items) {
    final counts = <TimeGroup, int>{};
    TimeGroup? current;
    for (final item in items) {
      if (item is TimeGroup) {
        current = item;
        counts[current] = 0;
      } else if (item is NoteMetaData && current != null) {
        counts[current] = (counts[current] ?? 0) + 1;
      }
    }
    return counts;
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
          final groupCounts = _countNotesPerGroup(state.groupedNotes);

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
                itemCount: state.groupedNotes.length,
                itemBuilder: (context, index) {
                  final item = state.groupedNotes[index];
                  if (item is TimeGroup) {
                    return HomeGroupHeader(
                      key: ValueKey('header_${item.category}_${item.customLabel}'),
                      group: item,
                      count: groupCounts[item],
                      isFirst: index == 0,
                    );
                  } else if (item is NoteMetaData) {
                    return HomeNoteCard(
                      key: ValueKey(item.id),
                      note: item,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
