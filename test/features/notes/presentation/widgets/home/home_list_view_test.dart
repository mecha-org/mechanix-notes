import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_event.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_state.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/time_group.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_group_label.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_list_view.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_note_card.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:widgets/widgets.dart';

class MockNotesBloc extends MockBloc<NotesEvent, NotesState>
    implements NotesBloc {}

class FakeNotesEvent extends Fake implements NotesEvent {}

void main() {
  late MockNotesBloc mockNotesBloc;

  setUpAll(() {
    registerFallbackValue(FakeNotesEvent());
  });

  setUp(() {
    mockNotesBloc = MockNotesBloc();
  });

  Widget buildTestWidget({required List<dynamic> groupedNotes}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<NotesBloc>.value(
        value: mockNotesBloc,
        child: Scaffold(body: HomeListView(groupedNotes: groupedNotes)),
      ),
    );
  }

  final note1 = NoteMetaData(
    id: 'n1',
    title: 'Daily Journal',
    previewText: 'Today started off with one of my new-found favourite bre...',
    createdAt: DateTime(2026, 9, 9, 9, 0),
    updatedAt: DateTime(2026, 9, 9, 10, 0),
    height: 60.0,
  );

  final note2 = NoteMetaData(
    id: 'n2',
    title: 'Skit dialogues',
    previewText: 'Skit dialogues',
    createdAt: DateTime(2026, 8, 21, 13, 0),
    updatedAt: DateTime(2026, 8, 21, 14, 0),
    height: 60.0,
  );

  final note3 = NoteMetaData(
    id: 'n3',
    title: 'Culinary- curry',
    previewText: 'Culinary- curry',
    createdAt: DateTime(2026, 8, 21, 14, 0),
    updatedAt: DateTime(2026, 8, 21, 15, 0),
    height: 60.0,
  );

  final note4 = NoteMetaData(
    id: 'n4',
    title: 'Travel with family',
    previewText: 'Travel with family- rollercoaster ride irl!! So I...',
    createdAt: DateTime(2026, 8, 9, 8, 0),
    updatedAt: DateTime(2026, 8, 9, 9, 0),
    height: 60.0,
  );

  group('HomeListView with Grouped Notes', () {
    testWidgets('renders headers and note cards for Recent and Yesterday', (
      tester,
    ) async {
      final groupedNotes = [
        const TimeGroup(TimeCategory.recent),
        note1,
        note2,
        note3,
        const TimeGroup(TimeCategory.yesterday),
        note4,
      ];

      when(
        () => mockNotesBloc.state,
      ).thenReturn(NotesState(groupedNotes: groupedNotes));

      await tester.pumpWidget(buildTestWidget(groupedNotes: groupedNotes));
      await tester.pumpAndSettle();

      // Verify headers rendered
      expect(find.byType(HomeGroupHeader), findsNWidgets(2));

      // Verify headers text
      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('[01]'), findsOneWidget);

      // Verify notes rendered inside virtualized list
      expect(find.text('Daily Journal'), findsOneWidget);
      expect(find.text('09 SEP'), findsOneWidget);
      expect(find.text('Skit dialogues'), findsOneWidget);
      expect(find.text('21 AUG'), findsNWidgets(2));
      expect(find.text('Culinary- curry'), findsOneWidget);
      expect(find.text('Travel with family'), findsOneWidget);
      expect(find.text('09 AUG'), findsOneWidget);
    });

    testWidgets('renders flat virtualized list of headers and note cards', (
      tester,
    ) async {
      final groupedNotes = [const TimeGroup(TimeCategory.recent), note1];

      when(
        () => mockNotesBloc.state,
      ).thenReturn(NotesState(groupedNotes: groupedNotes));

      await tester.pumpWidget(buildTestWidget(groupedNotes: groupedNotes));
      await tester.pumpAndSettle();

      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('Daily Journal'), findsOneWidget);
      expect(find.byType(HomeGroupHeader), findsOneWidget);
      expect(find.byType(HomeNoteCard), findsOneWidget);
    });

    testWidgets('renders Pinned section and pin icon for pinned notes', (
      tester,
    ) async {
      final pinnedNote = NoteMetaData(
        id: 'p1',
        title: 'Important Note',
        previewText: 'This note is pinned',
        createdAt: DateTime(2026, 9, 9, 9, 0),
        updatedAt: DateTime(2026, 9, 9, 10, 0),
        height: 60.0,
        isPinned: true,
      );

      final groupedNotes = [
        const TimeGroup(TimeCategory.pinned),
        pinnedNote,
        const TimeGroup(TimeCategory.recent),
        note1,
      ];

      when(
        () => mockNotesBloc.state,
      ).thenReturn(NotesState(groupedNotes: groupedNotes));

      await tester.pumpWidget(buildTestWidget(groupedNotes: groupedNotes));
      await tester.pumpAndSettle();

      expect(find.text('Pinned'), findsOneWidget);
      expect(find.text('Important Note'), findsOneWidget);
      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('Daily Journal'), findsOneWidget);

      final imageIconFinder = find.byType(ImageIcon);
      expect(imageIconFinder, findsOneWidget);
      final imageIcon = tester.widget<ImageIcon>(imageIconFinder);
      expect(imageIcon.image, const AssetImage(NotesIcon.pinIcon));

      final noteCardTile = tester.widget<MechanixListTile>(
        find.descendant(
          of: find.byType(HomeNoteCard).first,
          matching: find.byType(MechanixListTile),
        ),
      );
      expect(noteCardTile.leading, isA<ImageIcon>());
      expect(noteCardTile.trailingWidgets, isEmpty);
    });

    testWidgets(
      'renders MechanixExpandableListTile and collapses on header tap',
      (tester) async {
        final groupedNotes = [const TimeGroup(TimeCategory.recent), note1];

        when(
          () => mockNotesBloc.state,
        ).thenReturn(NotesState(groupedNotes: groupedNotes));

        await tester.pumpWidget(buildTestWidget(groupedNotes: groupedNotes));
        await tester.pumpAndSettle();

        // Find the expandable list tile
        expect(find.byType(MechanixExpandableListTile), findsOneWidget);
        expect(find.text('Daily Journal'), findsOneWidget);

        // Tap header to collapse
        await tester.tap(find.text('Recent'));
        await tester.pumpAndSettle();

        // Tap header again to expand
        await tester.tap(find.text('Recent'));
        await tester.pumpAndSettle();

        expect(find.text('Daily Journal'), findsOneWidget);
      },
    );
  });
}
