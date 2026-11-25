import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/intl.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_group_label.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_note_card.dart';

import 'notes_test_app.dart';

/// The home list: display, grouping, pinning and deleting.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Notes list', () {
    testWidgets('with no notes it invites you to write one', (tester) async {
      final app = await NotesTestApp.launch(tester);

      expect(find.text('NOTES'), findsOneWidget);
      expect(find.text('Write a note'), findsOneWidget);
      expect(app.createButton, findsOneWidget);
      expect(find.byType(HomeNoteCard), findsNothing);
    });

    testWidgets('shows each note with title, preview and date, newest first', (
      tester,
    ) async {
      final now = DateTime.now();
      final app = await NotesTestApp.launch(
        tester,
        seed: [
          SeedNote(
            'Older.md',
            '# Older\nolder body\n',
            modified: now.subtract(const Duration(minutes: 30)),
          ),
          SeedNote('Newer.md', '# Newer\nnewer body\n', modified: now),
        ],
      );
      await app.waitForNoteCard('Older');

      expect(find.text('Write a note'), findsNothing);
      expect(app.homeTitles, ['Newer', 'Older']);
      expect(find.text('newer body'), findsOneWidget);
      expect(find.text('older body'), findsOneWidget);
      final date = DateFormat('dd MMM').format(now).toUpperCase();
      expect(
        find.descendant(of: app.noteCard('Newer'), matching: find.text(date)),
        findsOneWidget,
      );
      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('[02]'), findsNothing); // Recent shows no count
    });
  });

  /// Group header labels, top to bottom.
  List<String> groupLabels(WidgetTester tester) => tester
      .widgetList<HomeGroupHeader>(find.byType(HomeGroupHeader))
      .map((h) => h.group.customLabel ?? h.group.category.name)
      .toList();

  group('Home list grouping', () {
    testWidgets('notes land in the group for their last change', (
      tester,
    ) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final old = today.subtract(const Duration(days: 75));
      // "Today" means earlier today but more than 2 hours ago; that only
      // exists after 02:00.
      final hasToday = now.hour >= 3;

      final app = await NotesTestApp.launch(
        tester,
        seed: [
          SeedNote('Fresh.md', '# Fresh\n', modified: now),
          if (hasToday)
            SeedNote(
              'Morning.md',
              '# Morning\n',
              modified: now.subtract(const Duration(hours: 2, minutes: 30)),
            ),
          SeedNote(
            'Yesterday note.md',
            '# Yesterday note\n',
            modified: today.subtract(const Duration(hours: 12)),
          ),
          SeedNote(
            'Week note.md',
            '# Week note\n',
            modified: today.subtract(const Duration(days: 4, hours: -10)),
          ),
          SeedNote('Old note.md', '# Old note\n', modified: old),
        ],
      );
      await app.waitForNoteCard('Old note');

      final oldLabel = DateFormat('MMMM yyyy', 'en').format(old);
      expect(groupLabels(tester), [
        'recent',
        if (hasToday) 'today',
        'yesterday',
        'last7Days',
        oldLabel,
      ]);
      expect(app.homeTitles, [
        'Fresh',
        if (hasToday) 'Morning',
        'Yesterday note',
        'Week note',
        'Old note',
      ]);
      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Last 7 Days'), findsOneWidget);
      expect(find.text(oldLabel), findsOneWidget);
    });

    testWidgets('editing an old note moves it to Recent', (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final app = await NotesTestApp.launch(
        tester,
        seed: [
          const SeedNote('Fresh.md', '# Fresh\n'),
          SeedNote('Stale.md', '# Stale\nold text\n', modified: yesterday),
        ],
      );
      await app.waitForNoteCard('Stale');
      expect(app.homeTitles, ['Fresh', 'Stale']);
      expect(find.text('Yesterday'), findsOneWidget);

      await app.openNote('Stale');
      await app.setText('# Stale\nnew text');
      await app.goBack();

      await app.pumpUntil(
        () => app.homeTitles.first == 'Stale',
        reason: 'Stale moved to the top',
      );
      expect(groupLabels(tester), ['recent']);
      expect(find.text('Yesterday'), findsNothing);
    });
  });

  final pinSeed = [
    const SeedNote('Alpha.md', '# Alpha\nfirst note\n'),
    SeedNote(
      'Beta.md',
      '# Beta\nsecond note\n',
      modified: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ];

  group('Pinning', () {
    testWidgets('pinning from the home card moves the note to Pinned', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester, seed: pinSeed);
      await app.waitForNoteCard('Beta');
      expect(app.homeTitles, ['Alpha', 'Beta']);
      expect(find.text('Pinned'), findsNothing);

      await app.tapCardAction('Beta', pin: true);

      await app.pumpUntil(
        () => app.homeTitles.first == 'Beta' && app.isPinnedOnHome('Beta'),
        reason: 'Beta pinned at the top',
      );
      expect(find.text('Pinned'), findsOneWidget);
      expect(app.isPinnedOnHome('Alpha'), isFalse);
    });

    testWidgets('unpinning from the home card returns the note to its group', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester, seed: pinSeed);
      await app.tapCardAction('Beta', pin: true);
      await app.waitFor(find.text('Pinned'));

      await app.tapCardAction('Beta', pin: true);

      await app.pumpUntil(
        () => !app.isPinnedOnHome('Beta'),
        reason: 'Beta unpinned',
      );
      await app.waitForAbsent(find.text('Pinned'));
      // Back in date order: Alpha is newer.
      expect(app.homeTitles, ['Alpha', 'Beta']);
    });

    testWidgets('pin and unpin from the editor menu show on the home list', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester, seed: pinSeed);

      await app.openNote('Beta');
      await app.tapEditorMenuItem('Pin note');
      await app.goBack();

      await app.pumpUntil(
        () => app.isPinnedOnHome('Beta'),
        reason: 'Beta pinned from the editor',
      );
      expect(app.homeTitles.first, 'Beta');

      await app.openNote('Beta');
      await app.openEditorMenu();
      expect(find.text('Unpin note'), findsOneWidget);
      await tester.tap(find.text('Unpin note'));
      await app.pumpFor(const Duration(milliseconds: 400));
      await app.goBack();

      await app.pumpUntil(
        () => !app.isPinnedOnHome('Beta'),
        reason: 'Beta unpinned from the editor',
      );
      expect(find.text('Pinned'), findsNothing);
    });

    testWidgets('pin state survives an app restart', (tester) async {
      var app = await NotesTestApp.launch(tester, seed: pinSeed);
      await app.tapCardAction('Beta', pin: true);
      await app.pumpUntil(() => app.isPinnedOnHome('Beta'));

      app = await app.restart();

      await app.waitForNoteCard('Beta');
      expect(app.isPinnedOnHome('Beta'), isTrue);
      expect(app.isPinnedOnHome('Alpha'), isFalse);
      expect(find.text('Pinned'), findsOneWidget);
    });
  });

  const deleteSeed = [
    SeedNote('Delete me.md', '# Delete me\n'),
    SeedNote('Stay.md', '# Stay\n'),
  ];

  group('Delete from home', () {
    testWidgets('confirming removes the card and the file', (tester) async {
      final app = await NotesTestApp.launch(tester, seed: deleteSeed);

      await app.tapCardAction('Delete me', pin: false);
      expect(find.text('Do you want to delete this note?'), findsOneWidget);
      await tester.tap(find.text('DELETE'));

      await app.waitForAbsent(app.noteCard('Delete me'));
      await app.waitForFileGone('Delete me.md');
      expect(app.homeTitles, ['Stay']);
      expect(app.noteFiles, ['Stay.md']);
    });

    testWidgets('cancelling keeps the note', (tester) async {
      final app = await NotesTestApp.launch(tester, seed: deleteSeed);

      await app.tapCardAction('Delete me', pin: false);
      await tester.tap(find.text('CANCEL'));
      await app.pumpFor(const Duration(milliseconds: 800));

      expect(find.text('Do you want to delete this note?'), findsNothing);
      expect(app.noteCard('Delete me'), findsOneWidget);
      expect(app.noteFiles, ['Delete me.md', 'Stay.md']);
    });
  });
}
