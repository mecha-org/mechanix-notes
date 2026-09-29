import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_event.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_state.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/time_group.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/card/home_card_selection_icon.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_group_label.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_list_view.dart';
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
        child: Scaffold(
          body: HomeListView(groupedNotes: groupedNotes),
        ),
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

  group('HomeListView with Accordion Groups', () {
    testWidgets('renders accordion sections for Recent and Yesterday', (
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

      when(() => mockNotesBloc.state).thenReturn(
        NotesState(groupedNotes: groupedNotes),
      );

      await tester.pumpWidget(buildTestWidget(groupedNotes: groupedNotes));
      await tester.pumpAndSettle();

      // Verify accordion sections rendered
      expect(find.byType(HomeGroupAccordion), findsNWidgets(2));
      expect(find.byType(MechanixExpandableListTile), findsNWidgets(2));

      // Verify headers
      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('[01]'), findsOneWidget);

      // Verify notes rendered inside expanded sections
      expect(find.text('Daily Journal'), findsOneWidget);
      expect(find.text('09 SEP'), findsOneWidget);
      expect(find.text('Skit dialogues'), findsOneWidget);
      expect(find.text('21 AUG'), findsNWidgets(2));
      expect(find.text('Culinary- curry'), findsOneWidget);
      expect(find.text('Travel with family'), findsOneWidget);
      expect(find.text('09 AUG'), findsOneWidget);
    });

    testWidgets('tapping accordion toggle button collapses section', (
      tester,
    ) async {
      final groupedNotes = [
        const TimeGroup(TimeCategory.recent),
        note1,
      ];

      when(() => mockNotesBloc.state).thenReturn(
        NotesState(groupedNotes: groupedNotes),
      );

      await tester.pumpWidget(buildTestWidget(groupedNotes: groupedNotes));
      await tester.pumpAndSettle();

      expect(find.text('Daily Journal'), findsOneWidget);

      // Tap accordion chevron button to collapse
      final accordionButtons = find.byType(MechanixAccordionButton);
      expect(accordionButtons, findsOneWidget);
      await tester.tap(accordionButtons.first);
      await tester.pumpAndSettle();

      // Child is now collapsed (height factor 0.0)
      final alignFinder = find.descendant(
        of: find.byType(ClipRect),
        matching: find.byType(Align),
      );
      final align = tester.widget<Align>(alignFinder.first);
      expect(align.heightFactor, equals(0.0));
    });

    testWidgets('selection mode renders selection checkboxes and toggles on tap', (
      tester,
    ) async {
      final groupedNotes = [
        const TimeGroup(TimeCategory.recent),
        note1,
      ];

      when(() => mockNotesBloc.state).thenReturn(
        NotesState(
          groupedNotes: groupedNotes,
          isSelectionMode: true,
          selectedNotes: const ['n1'],
        ),
      );

      await tester.pumpWidget(buildTestWidget(groupedNotes: groupedNotes));
      await tester.pumpAndSettle();

      // Checkbox is visible
      expect(find.byType(HomeCardSelectionIcon), findsOneWidget);

      // Tap note to toggle selection
      await tester.tap(find.text('Daily Journal'));
      await tester.pumpAndSettle();

      verify(
        () => mockNotesBloc.add(
          any(
            that: isA<ToggleNoteSelection>().having(
              (e) => e.noteId,
              'noteId',
              'n1',
            ),
          ),
        ),
      ).called(1);
    });
  });
}
