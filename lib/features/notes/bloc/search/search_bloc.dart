import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/core/utils/constants.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_event.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_state.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final NoteRepository noteRepository;
  late final StreamSubscription<Set<String>> _removalsSub;

  /// Ids removed while a search was in flight; that search may have read the
  /// index before the removal and must not show them.
  final Set<String> _removedDuringSearch = {};

  SearchBloc({required this.noteRepository}) : super(const SearchState()) {
    on<SearchQueryChanged>(_onSearchQueryChanged, transformer: restartable());
    on<LoadMoreSearchResults>(
      _onLoadMoreSearchResults,
      transformer: droppable(),
    );
    on<ClearSearch>(_onClearSearch);
    on<SearchNotesRemoved>(_onNotesRemoved);

    // A note deleted from the editor is removed from the index after the
    // editor has already popped, so the re-run search can still return it.
    _removalsSub = noteRepository.noteRemovals.listen(
      (ids) => add(SearchNotesRemoved(ids: ids)),
    );
  }

  @override
  Future<void> close() async {
    await _removalsSub.cancel();
    return super.close();
  }

  Future<void> _onSearchQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query.trim();
    if (query.length < Constants.minSearchQueryLength) {
      emit(const SearchState());
      return;
    }

    emit(
      state.copyWith(
        status: SearchStatus.loading,
        query: query,
        isLoadingMore: false,
      ),
    );
    AppLogger.i("Searching notes for query: $query");

    _removedDuringSearch.clear();
    try {
      var ids = await noteRepository.searchNoteIds(query);
      var firstPage = await noteRepository.getNotesMetaData(_pageIds(ids, 0));
      if (_removedDuringSearch.isNotEmpty) {
        bool kept(String id) => !_removedDuringSearch.contains(id);
        ids = ids.where(kept).toList();
        firstPage = firstPage.where((n) => kept(n.id)).toList();
      }

      AppLogger.i("Found ${ids.length} matching notes");

      emit(
        state.copyWith(
          status: SearchStatus.success,
          results: firstPage,
          resultIds: ids,
          hasMore: ids.length > firstPage.length,
          currentPage: 0,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      AppLogger.e("Error searching notes: $e");
      emit(state.copyWith(status: SearchStatus.failure, isLoadingMore: false));
    }
  }

  Future<void> _onLoadMoreSearchResults(
    LoadMoreSearchResults event,
    Emitter<SearchState> emit,
  ) async {
    if (state.isLoadingMore || !state.hasMore) return;

    AppLogger.i("Loading more search results");
    final ids = state.resultIds;
    final nextPage = state.currentPage + 1;
    // Offset by what is loaded, not by page number: removals shift the ids.
    final loaded = state.results.length;
    final pageIds = ids.skip(loaded).take(Constants.pageSize).toList();

    if (pageIds.isEmpty) {
      emit(state.copyWith(hasMore: false));
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    try {
      final newBatch = await noteRepository.getNotesMetaData(pageIds);

      if (_isStale(ids)) return;

      emit(
        state.copyWith(
          results: [...state.results, ...newBatch],
          isLoadingMore: false,
          hasMore: loaded + pageIds.length < ids.length,
          currentPage: nextPage,
        ),
      );
    } catch (e) {
      AppLogger.e("Error loading more search results: $e");
      if (!_isStale(ids)) emit(state.copyWith(isLoadingMore: false));
    }
  }

  bool _isStale(List<String> ids) =>
      state.status != SearchStatus.success || !identical(state.resultIds, ids);

  static List<String> _pageIds(List<String> ids, int page) =>
      ids.skip(page * Constants.pageSize).take(Constants.pageSize).toList();

  void _onNotesRemoved(SearchNotesRemoved event, Emitter<SearchState> emit) {
    final ids = event.ids;
    _removedDuringSearch.addAll(ids);
    if (!state.resultIds.any(ids.contains)) return;

    final remainingIds = state.resultIds
        .where((id) => !ids.contains(id))
        .toList();
    final remainingResults = state.results
        .where((n) => !ids.contains(n.id))
        .toList();

    emit(
      state.copyWith(
        results: remainingResults,
        resultIds: remainingIds,
        hasMore: remainingResults.length < remainingIds.length,
      ),
    );
  }

  void _onClearSearch(ClearSearch event, Emitter<SearchState> emit) {
    emit(const SearchState());
  }
}
