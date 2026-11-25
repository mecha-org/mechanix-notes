import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'notes_test_app.dart';

/// Coarse timing checks. Limits are generous because these run as debug
/// builds; each result is also reported through the binding's reportData.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Performance', () {
    testWidgets('starts and lists 300 notes quickly', (tester) async {
      final now = DateTime.now();
      final seed = [
        for (var i = 0; i < 300; i++)
          SeedNote(
            'Note $i.md',
            '# Note $i\n${'content ' * 30}\n',
            modified: now.subtract(Duration(minutes: i)),
          ),
      ];

      final watch = Stopwatch()..start();
      final app = await NotesTestApp.launch(tester, seed: seed);
      await app.waitForNoteCard('Note 0');
      watch.stop();

      binding.reportData = {
        ...?binding.reportData,
        'startup_300_notes_ms': watch.elapsedMilliseconds,
      };
      expect(watch.elapsed, lessThan(const Duration(seconds: 20)));

      // Scrolling to the end of the list works.
      await tester.fling(app.noteCard('Note 0'), const Offset(0, -20000), 8000);
      await app.waitForNoteCard('Note 299');
    });

    testWidgets('typing stays responsive and the final text is saved', (
      tester,
    ) async {
      final app = await NotesTestApp.launch(tester);
      await app.createNote();

      final watch = Stopwatch()..start();
      var text = '# Fast typing\n';
      for (var i = 0; i < 200; i++) {
        text += 'w$i ';
        await app.setText(text);
      }
      watch.stop();

      binding.reportData = {
        ...?binding.reportData,
        'typing_200_edits_ms': watch.elapsedMilliseconds,
      };
      expect(watch.elapsed, lessThan(const Duration(seconds: 20)));

      await app.goBack();
      expect(await app.waitForFile('Fast typing.md'), '$text\n');
      expect(app.noteFiles, ['Fast typing.md']);
    });
  });
}
