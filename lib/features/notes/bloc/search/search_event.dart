abstract class SearchEvent {}

class SearchQueryChanged extends SearchEvent {
  final String query;
  SearchQueryChanged({required this.query});
}

class LoadMoreSearchResults extends SearchEvent {}

class ClearSearch extends SearchEvent {}

/// Notes were removed from the index; drop them from the current results.
class SearchNotesRemoved extends SearchEvent {
  final Set<String> ids;
  SearchNotesRemoved({required this.ids});
}
