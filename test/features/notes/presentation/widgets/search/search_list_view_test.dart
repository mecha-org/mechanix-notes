import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_event.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_state.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/search/search_list_view.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:widgets/widgets.dart';

class MockSearchBloc extends MockBloc<SearchEvent, SearchState>
    implements SearchBloc {}

class FakeSearchEvent extends Fake implements SearchEvent {}

/// Paging: the next page of results loads when the list nears its end.
void main() {
  late MockSearchBloc bloc;

  setUpAll(() => registerFallbackValue(FakeSearchEvent()));
  setUp(() => bloc = MockSearchBloc());

  List<NoteMetaData> notes(int count) => [
    for (var i = 0; i < count; i++)
      NoteMetaData(
        id: 'n$i.md',
        title: 'Note $i',
        previewText: 'preview $i',
        updatedAt: DateTime(2026, 10, 1),
      ),
  ];

  Future<void> pumpList(WidgetTester tester, SearchState state) async {
    when(() => bloc.state).thenReturn(state);
    await tester.pumpWidget(
      BlocProvider<SearchBloc>.value(
        value: bloc,
        child: MaterialApp(
          theme: MechanixTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SearchListView(query: 'note')),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> scrollToEnd(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -10000));
    await tester.pump();
  }

  SearchState stateWith(
    int loaded, {
    required bool hasMore,
    bool isLoadingMore = false,
  }) {
    final results = notes(loaded);
    return SearchState(
      status: SearchStatus.success,
      query: 'note',
      results: results,
      resultIds: [
        ...results.map((n) => n.id),
        if (hasMore) ...['more1.md', 'more2.md'],
      ],
      hasMore: hasMore,
      isLoadingMore: isLoadingMore,
    );
  }

  testWidgets('does not load more before the end of the list', (
    tester,
  ) async {
    await pumpList(tester, stateWith(20, hasMore: true));

    verifyNever(() => bloc.add(any(that: isA<LoadMoreSearchResults>())));
  });

  testWidgets('scrolling to the end loads the next page', (tester) async {
    await pumpList(tester, stateWith(20, hasMore: true));

    await scrollToEnd(tester);

    verify(
      () => bloc.add(any(that: isA<LoadMoreSearchResults>())),
    ).called(greaterThanOrEqualTo(1));
  });

  testWidgets('does not load more when every result is shown', (
    tester,
  ) async {
    await pumpList(tester, stateWith(20, hasMore: false));

    await scrollToEnd(tester);

    verifyNever(() => bloc.add(any(that: isA<LoadMoreSearchResults>())));
  });

  testWidgets('does not ask again while a page is loading', (tester) async {
    await pumpList(tester, stateWith(20, hasMore: true, isLoadingMore: true));

    await scrollToEnd(tester);

    verifyNever(() => bloc.add(any(that: isA<LoadMoreSearchResults>())));
  });
}
