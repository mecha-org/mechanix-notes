abstract class SearchEvent {}

class SearchQueryChanged extends SearchEvent {
  final String query;
  SearchQueryChanged({required this.query});
}

class LoadMoreSearchResults extends SearchEvent {}

class ClearSearch extends SearchEvent {}

class SearchResultRemoved extends SearchEvent {
  final String noteId;
  SearchResultRemoved({required this.noteId});
}
