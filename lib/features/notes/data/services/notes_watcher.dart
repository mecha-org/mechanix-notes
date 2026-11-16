import 'dart:async';
import 'dart:io';

import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/features/notes/data/services/note_file_storage.dart';

enum NotesWatcherEventType { create, modify, delete, move }

class NotesWatcherEvent {
  final NotesWatcherEventType type;
  final String fileName;
  final String? oldFileName;
  final String fullPath;

  const NotesWatcherEvent({
    required this.type,
    required this.fileName,
    this.oldFileName,
    required this.fullPath,
  });

  @override
  String toString() =>
      'NotesWatcherEvent($type, fileName: $fileName, oldFileName: $oldFileName)';
}

class NotesWatcher {
  final Directory _notesDirectory;
  final Duration debounceDuration;
  final StreamController<NotesWatcherEvent> _eventController =
      StreamController<NotesWatcherEvent>.broadcast();
  final Map<String, Timer> _debounceTimers = {};

  StreamSubscription<FileSystemEvent>? _dirSubscription;
  bool _running = false;

  NotesWatcher({
    required Directory notesDirectory,
    this.debounceDuration = const Duration(milliseconds: 300),
  }) : _notesDirectory = notesDirectory;

  Stream<NotesWatcherEvent> get events => _eventController.stream;

  bool get isRunning => _running;

  /// Starts monitoring the notes directory for filesystem changes.
  Future<void> start() async {
    if (_running) return;
    try {
      if (!await _notesDirectory.exists()) {
        await _notesDirectory.create(recursive: true);
      }

      _dirSubscription = _notesDirectory
          .watch(events: FileSystemEvent.all, recursive: false)
          .listen(
            _handleFileSystemEvent,
            onError: (error) {
              AppLogger.e('[NotesWatcher] Watch error: $error. Restarting...');
              restart();
            },
            onDone: () {
              AppLogger.d('[NotesWatcher] Watch stream closed. Restarting...');
              restart();
            },
          );

      _running = true;
      AppLogger.i('[NotesWatcher] Watching ${_notesDirectory.path}');
    } catch (e) {
      AppLogger.e('[NotesWatcher] Failed to start watcher: $e');
      _running = false;
    }
  }

  /// Restarts the directory watcher after error or stream termination.
  Future<void> restart() async {
    await stop();
    await Future.delayed(const Duration(seconds: 1));
    await start();
  }

  /// Stops monitoring the directory.
  Future<void> stop() async {
    _running = false;
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    await _dirSubscription?.cancel();
    _dirSubscription = null;
    AppLogger.i('[NotesWatcher] Stopped');
  }

  /// Disposes resources held by the watcher.
  Future<void> dispose() async {
    await stop();
    await _eventController.close();
  }

  static bool isTrackedFile(String path) {
    final fileName = File(path).uri.pathSegments.last;
    if (fileName.isEmpty) return false;
    // Skip hidden files (.mechanix, .obsidian, etc.)
    if (fileName.startsWith('.')) return false;
    // Skip temp files
    if (fileName.startsWith('..tmp_')) return false;
    // Only track Markdown files
    return fileName.endsWith('.md');
  }

  void _handleFileSystemEvent(FileSystemEvent event) {
    final path = event.path;
    final destination = event is FileSystemMoveEvent ? event.destination : null;

    final isTrackedSource = isTrackedFile(path);
    final isTrackedDest = destination != null && isTrackedFile(destination);

    if (!isTrackedSource && !isTrackedDest) return;

    if (event is FileSystemMoveEvent && destination != null) {
      final oldName = File(path).uri.pathSegments.last;
      final newName = File(destination).uri.pathSegments.last;

      if (!isTrackedSource && isTrackedDest) {
        // Moved from non-tracked into tracked -> treat as create
        _debounce(
          newName,
          () => _emitIfExternal(
            NotesWatcherEvent(
              type: NotesWatcherEventType.create,
              fileName: newName,
              fullPath: destination,
            ),
          ),
        );
      } else if (isTrackedSource && !isTrackedDest) {
        // Moved from tracked to non-tracked -> treat as delete
        _debounce(
          oldName,
          () => _emit(
            NotesWatcherEvent(
              type: NotesWatcherEventType.delete,
              fileName: oldName,
              fullPath: path,
            ),
          ),
        );
      } else {
        // True rename within tracked directory
        _debounce(
          newName,
          () => _emitIfExternal(
            NotesWatcherEvent(
              type: NotesWatcherEventType.move,
              fileName: newName,
              oldFileName: oldName,
              fullPath: destination,
            ),
          ),
        );
      }
      return;
    }

    final fileName = File(path).uri.pathSegments.last;

    switch (event.type) {
      case FileSystemEvent.create:
        _debounce(
          fileName,
          () => _emitIfExternal(
            NotesWatcherEvent(
              type: NotesWatcherEventType.create,
              fileName: fileName,
              fullPath: path,
            ),
          ),
        );
      case FileSystemEvent.modify:
        _debounce(
          fileName,
          () => _emitIfExternal(
            NotesWatcherEvent(
              type: NotesWatcherEventType.modify,
              fileName: fileName,
              fullPath: path,
            ),
          ),
        );
      case FileSystemEvent.delete:
        _debounce(
          fileName,
          () => _emit(
            NotesWatcherEvent(
              type: NotesWatcherEventType.delete,
              fileName: fileName,
              fullPath: path,
            ),
          ),
        );
    }
  }

  Future<void> _emitIfExternal(NotesWatcherEvent event) async {
    try {
      final file = File(event.fullPath);
      if (!await file.exists()) return;
      final stat = await file.stat();

      // Check self-write suppression
      if (NoteFileStorage.isRecentSelfWrite(event.fileName, stat.modified)) {
        AppLogger.d(
          '[NotesWatcher] Dropped self-write event for ${event.fileName}',
        );
        return;
      }

      _emit(event);
    } catch (e) {
      AppLogger.d('[NotesWatcher] Error inspecting ${event.fileName}: $e');
    }
  }

  void _debounce(String key, void Function() action) {
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(debounceDuration, () {
      _debounceTimers.remove(key);
      action();
    });
  }

  void _emit(NotesWatcherEvent event) {
    if (!_eventController.isClosed) {
      AppLogger.d('[NotesWatcher] Emitting $event');
      _eventController.add(event);
    }
  }
}
