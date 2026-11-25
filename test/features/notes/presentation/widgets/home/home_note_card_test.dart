import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_event.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_state.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_trash_confirmation_sheet.dart';
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

  final testNote = NoteMetaData(
    id: 'test-note-1',
    title: 'Test Note',
    previewText: 'Preview text for test note',
    updatedAt: DateTime(2026, 9, 9, 10, 0),
  );

  Widget buildWidget({VoidCallback? onDelete, NoteMetaData? note}) {
    return MaterialApp(
      theme: MechanixTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<NotesBloc>.value(
        value: mockNotesBloc,
        child: Scaffold(
          body: SizedBox(
            height: 100,
            child: HomeNoteCard(
              note: note ?? testNote,
              onDelete: onDelete,
            ),
          ),
        ),
      ),
    );
  }

  /// Pin icons shown in the card itself (not in its swipe actions).
  Finder leadingPinIcon() => find.descendant(
    of: find.byType(HomeNoteCard),
    matching: find.byWidgetPredicate(
      (w) =>
          w is ImageIcon &&
          (w.image as AssetImage).assetName == NotesIcon.pinIcon &&
          w.size == 20,
    ),
  );

  testWidgets('pin action dispatches TogglePinNote for the note', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(HomeNoteCard), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('pin_action_${testNote.id}')));
    await tester.pumpAndSettle();

    verify(
      () => mockNotesBloc.add(
        any(
          that: isA<TogglePinNote>().having(
            (e) => e.noteId,
            'noteId',
            testNote.id,
          ),
        ),
      ),
    ).called(1);
  });

  testWidgets('a pinned note shows a pin icon; an unpinned one does not', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();
    expect(leadingPinIcon(), findsNothing);

    await tester.pumpWidget(
      buildWidget(note: testNote.copyWith(isPinned: true)),
    );
    await tester.pumpAndSettle();
    expect(leadingPinIcon(), findsOneWidget);
  });

  testWidgets('pressing delete action opens EditorTrashConfirmationSheet and confirms delete', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    // Swipe open to reveal actions
    await tester.drag(find.byType(HomeNoteCard), const Offset(-300, 0));
    await tester.pumpAndSettle();

    // Tap delete action
    final deleteButton = find.byKey(ValueKey('delete_action_${testNote.id}'));
    expect(deleteButton, findsOneWidget);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    // Verify EditorTrashConfirmationSheet is displayed
    expect(find.byType(EditorTrashConfirmationSheet), findsOneWidget);

    // Tap the trash confirmation button
    final confirmButton = find.text('DELETE');
    expect(confirmButton, findsOneWidget);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    // Verify DeleteNotes event was dispatched to NotesBloc
    verify(
      () => mockNotesBloc.add(
        any(
          that: isA<DeleteNotes>().having(
            (e) => e.noteIds,
            'noteIds',
            [testNote.id],
          ),
        ),
      ),
    ).called(1);

    // Verify sheet is closed
    expect(find.byType(EditorTrashConfirmationSheet), findsNothing);
  });

  testWidgets('custom onDelete callback is called if provided', (tester) async {
    var customDeleteCalled = false;
    await tester.pumpWidget(buildWidget(onDelete: () {
      customDeleteCalled = true;
    }));
    await tester.pumpAndSettle();

    // Swipe open to reveal actions
    await tester.drag(find.byType(HomeNoteCard), const Offset(-300, 0));
    await tester.pumpAndSettle();

    // Tap delete action
    final deleteButton = find.byKey(ValueKey('delete_action_${testNote.id}'));
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(customDeleteCalled, isTrue);
    expect(find.byType(EditorTrashConfirmationSheet), findsNothing);
  });
}
