import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository_impl.dart';

import 'test_helper.dart';

/// Writes [count] notes straight to the database (much faster than the UI).
Future<void> seedNotes(int count) async {
  final repository = NoteRepositoryImpl();
  final now = DateTime.now();
  for (var i = 0; i < count; i++) {
    final body = 'Body of seeded note number $i with some searchable words.';
    await repository.upsertNote(
      NoteModel(
        id: 'seed-$i',
        title: 'Seeded note $i',
        content: 'Seeded note $i\n$body',
        plainText: 'Seeded note $i\n$body',
        previewText: body,
        createdAt: now.subtract(Duration(minutes: i)),
        updatedAt: now.subtract(Duration(minutes: i)),
        height: 0,
      ),
    );
  }
}

// Limits are generous: they catch hangs and big slowdowns, not small noise.
void main() {
  setUpIntegrationTests();

  appTest('list of 50 notes loads and scrolls', (tester) async {
    final stopwatch = Stopwatch()..start();
    await seedNotes(50);
    await waitFor(tester, find.text('Seeded note 0'));
    stopwatch.stop();
    debugPrint(
      'PERF seed + show 50 notes: ${stopwatch.elapsedMilliseconds} ms',
    );
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 10)));

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Seeded note 49'),
      300,
      scrollable: scrollable,
      maxScrolls: 100,
    );
    expect(find.text('Seeded note 49'), findsOneWidget);
  });

  appTest('opening the editor is fast', (tester) async {
    final stopwatch = Stopwatch()..start();
    await openNewNote(tester);
    stopwatch.stop();
    debugPrint('PERF open editor: ${stopwatch.elapsedMilliseconds} ms');
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
  });

  appTest('typing a long text stays responsive', (tester) async {
    await openNewNote(tester);
    await typeInEditor(tester, 'Typing test');

    final stopwatch = Stopwatch()..start();
    var text = 'Typing test\n';
    for (var i = 0; i < 100; i++) {
      text += 'word$i ';
      tester.testTextInput.enterText(text);
      await tester.pump();
    }
    stopwatch.stop();
    debugPrint('PERF 100 edits: ${stopwatch.elapsedMilliseconds} ms');
    expect(editorText(tester), text);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 10)));
  });

  appTest('search over 50 notes is fast', (tester) async {
    await seedNotes(50);
    await waitFor(tester, find.text('Seeded note 0'));
    await openSearch(tester);

    final stopwatch = Stopwatch()..start();
    await searchFor(tester, 'searchable');
    await waitFor(tester, searchResult('Seeded note'));
    stopwatch.stop();
    debugPrint('PERF search 50 notes: ${stopwatch.elapsedMilliseconds} ms');
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
  });
}
