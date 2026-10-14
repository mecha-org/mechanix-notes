import 'dart:async';
import 'dart:io';

import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:path/path.dart' as p;

/// Watches the notes directory for filesystem changes and triggers debounced
/// callbacks when external changes occur, ignoring internal self-writes.
class NoteDirectoryWatcher {
  final Directory directory;
  final Future<void> Function() onDirectoryChanged;
  final bool Function(String path) isInternalWrite;
  final Duration debounceDuration;

  StreamSubscription<FileSystemEvent>? _subscription;
  Timer? _debounceTimer;
  bool _isWatching = false;

  NoteDirectoryWatcher({
    required this.directory,
    required this.onDirectoryChanged,
    required this.isInternalWrite,
    this.debounceDuration = const Duration(milliseconds: 500),
  });

  bool get isWatching => _isWatching;

  /// Starts listening to filesystem events in [directory].
  void start() {
    stop();
    try {
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
      _subscription = directory
          .watch(events: FileSystemEvent.all, recursive: false)
          .listen(
            _handleEvent,
            onError: (e) {
              AppLogger.e('NoteDirectoryWatcher error: $e');
            },
          );
      _isWatching = true;
      AppLogger.i('NoteDirectoryWatcher started watching ${directory.path}');
    } catch (e) {
      AppLogger.e('NoteDirectoryWatcher failed to start: $e');
    }
  }

  void _handleEvent(FileSystemEvent event) {
    if (event.isDirectory) return;
    if (!event.path.endsWith('.md')) return;

    final fileName = p.basename(event.path);
    if (fileName.startsWith('..tmp_')) return;

    if (isInternalWrite(event.path) || isInternalWrite(fileName)) {
      AppLogger.d('NoteDirectoryWatcher: Ignoring internal write for $fileName');
      return;
    }

    AppLogger.i(
      'NoteDirectoryWatcher: External event (${event.type}) on $fileName',
    );
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () async {
      try {
        await onDirectoryChanged();
      } catch (e) {
        AppLogger.e('NoteDirectoryWatcher: onDirectoryChanged failed: $e');
      }
    });
  }

  /// Stops watching the directory and cancels active timers.
  void stop() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _isWatching = false;
  }

  void dispose() {
    stop();
  }
}
