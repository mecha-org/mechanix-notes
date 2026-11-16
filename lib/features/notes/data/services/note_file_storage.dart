import 'dart:io';

import 'package:mechanix_notes/core/exceptions/storage_exception.dart';
import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/core/utils/constants.dart';

class NoteFileStorage {
  static int _tempCounter = 0;
  static final Map<String, DateTime> _recentSelfWrites = {};
  final Directory _directory;

  NoteFileStorage({Directory? notesDirectory})
    : _directory = notesDirectory ?? _resolveDefaultDirectory();

  Directory get directory => _directory;

  /// Checks whether a modification event on [fileName] with [modifiedTime]
  /// was initiated by this app's own save routine.
  static bool isRecentSelfWrite(String fileName, DateTime modifiedTime) {
    final recorded = _recentSelfWrites[fileName];
    if (recorded == null) return false;
    final diff = modifiedTime.difference(recorded).abs();
    if (diff <= const Duration(seconds: 2)) return true;
    _recentSelfWrites.remove(fileName);
    return false;
  }

  /// Records an app-initiated write or rename for self-write echo suppression.
  static void recordSelfWrite(String fileName, DateTime modifiedTime) {
    _recentSelfWrites[fileName] = modifiedTime;
    final now = DateTime.now();
    _recentSelfWrites.removeWhere(
      (_, time) => now.difference(time) > const Duration(seconds: 10),
    );
  }

  static Directory _resolveDefaultDirectory() {
    final customDocs = Platform.environment['DOCUMENTS_DIR'];
    if (customDocs != null && customDocs.isNotEmpty) {
      return Directory('$customDocs/${Constants.notesSubDir}');
    }

    final xdgDocs = Platform.environment['XDG_DOCUMENTS_DIR'];
    if (xdgDocs != null && xdgDocs.isNotEmpty) {
      return Directory('$xdgDocs/${Constants.notesSubDir}');
    }

    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return Directory('$home/Documents/${Constants.notesSubDir}');
    }

    return Directory(
      '${Directory.current.path}/Documents/${Constants.notesSubDir}',
    );
  }

  /// Ensures that the target notes directory exists.
  Future<void> ensureDirectoryExists() async {
    try {
      if (!await _directory.exists()) {
        await _directory.create(recursive: true);
        AppLogger.i('[NoteFileStorage] Created directory: ${_directory.path}');
      }
    } catch (e) {
      AppLogger.e('[NoteFileStorage] Failed to create directory: $e');
      rethrow;
    }
  }

  /// Sanitizes note title for safe use as a filename on Linux filesystems.
  static String sanitizeFileName(String title) {
    var sanitized = title.trim();

    // Remove markdown heading tokens if present
    sanitized = sanitized.replaceAll(RegExp(r'^#+\s*'), '');

    // Replace illegal characters (\ / : * ? " < > | and control characters)
    sanitized = sanitized.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_');

    // Replace multiple spaces or underscores with a single space
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
    sanitized = sanitized.replaceAll(RegExp(r'_+'), '_');

    // Remove leading and trailing dots, spaces, underscores
    sanitized = sanitized.replaceAll(RegExp(r'^[._\s]+|[._\s]+$'), '');

    if (sanitized.isEmpty) {
      return Constants.defaultNoteFileName;
    }

    // Limit filename length to 100 characters to remain safely below Linux NAME_MAX (255 bytes)
    if (sanitized.length > 100) {
      sanitized = sanitized.substring(0, 100).trim();
    }

    return sanitized;
  }

  static bool isFileNameForTitle(String fileName, String title) {
    final baseName = sanitizeFileName(title);
    final currentBase = fileName.endsWith('.md')
        ? fileName.substring(0, fileName.length - 3)
        : fileName;
    return currentBase == baseName ||
        RegExp(
          '^${RegExp.escape(baseName)} \\(\\d+\\)\$',
        ).hasMatch(currentBase);
  }

  /// Creates a new note file named after [title] and returns its filename.
  Future<String> createNoteFile({
    required String title,
    required String markdown,
  }) async {
    await ensureDirectoryExists();
    final fileName = await _reserveFileName(title);
    try {
      await _writeAtomic(fileName, markdown);
    } catch (_) {
      await _releaseReservation(fileName);
      rethrow;
    }
    return fileName;
  }

  Future<String> updateNoteFile({
    required String fileName,
    required String title,
    required String markdown,
  }) async {
    await ensureDirectoryExists();
    final oldFile = File('${_directory.path}/$fileName');
    if (!await oldFile.exists()) {
      throw NoteFileMissingException(fileName);
    }

    if (isFileNameForTitle(fileName, title)) {
      await _writeAtomic(fileName, markdown);
      return fileName;
    }

    final targetFileName = await _reserveFileName(title);
    final targetPath = '${_directory.path}/$targetFileName';
    try {
      await oldFile.rename(targetPath);
      AppLogger.i(
        '[NoteFileStorage] Renamed note: $fileName -> $targetFileName',
      );
    } catch (e) {
      AppLogger.d(
        '[NoteFileStorage] Rename failed ($e), writing new file instead',
      );
    }

    try {
      await _writeAtomic(targetFileName, markdown);
    } catch (_) {
      // Only drop the reservation if the old file was not moved onto it.
      if (await oldFile.exists()) await _releaseReservation(targetFileName);
      rethrow;
    }

    if (await oldFile.exists()) {
      await oldFile.delete();
      AppLogger.i('[NoteFileStorage] Renamed note: removed old file $fileName');
    }
    return targetFileName;
  }

  Future<String> _reserveFileName(String title) async {
    final baseName = sanitizeFileName(title);
    for (var counter = 0; ; counter++) {
      final candidate = counter == 0
          ? '$baseName.md'
          : '$baseName ($counter).md';
      try {
        await File('${_directory.path}/$candidate').create(exclusive: true);
        return candidate;
      } on FileSystemException {
        if (await noteFileExists(candidate)) continue; // taken, try next
        rethrow;
      }
    }
  }

  /// Removes a reserved name that never received content.
  Future<void> _releaseReservation(String fileName) async {
    try {
      final file = File('${_directory.path}/$fileName');
      if (await file.exists() && await file.length() == 0) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Writes [markdown] to [fileName] via a temp file and an atomic rename,
  Future<void> _writeAtomic(String fileName, String markdown) async {
    final targetPath = '${_directory.path}/$fileName';
    final uniqueSuffix =
        '${DateTime.now().microsecondsSinceEpoch}_${++_tempCounter}';
    final baseName = fileName.endsWith('.md')
        ? fileName.substring(0, fileName.length - 3)
        : fileName;
    final tempFile = File(
      '${_directory.path}/..tmp_${baseName}_$uniqueSuffix.md',
    );
    try {
      await tempFile.writeAsString(markdown, flush: true);
      await tempFile.rename(targetPath);
      AppLogger.i('[NoteFileStorage] Saved note to $fileName');

      final stat = await File(targetPath).stat();
      recordSelfWrite(fileName, stat.modified);
    } catch (e) {
      AppLogger.e('[NoteFileStorage] Failed to write note to $fileName: $e');
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Reads Markdown content for the given [fileName].
  /// Returns null if the file does not exist.
  Future<String?> readNoteContent(String fileName) async {
    try {
      final file = File('${_directory.path}/$fileName');
      if (!await file.exists()) {
        AppLogger.d('[NoteFileStorage] File not found: $fileName');
        return null;
      }
      return await file.readAsString();
    } catch (e) {
      AppLogger.e('[NoteFileStorage] Failed to read note $fileName: $e');
      rethrow;
    }
  }

  /// Safely deletes the given [fileName] and any leftover temporary file.
  Future<void> deleteNoteFile(String fileName) async {
    try {
      final file = File('${_directory.path}/$fileName');
      if (await file.exists()) {
        await file.delete();
        AppLogger.i('[NoteFileStorage] Deleted file: $fileName');
      }

      final tempFile = File('${_directory.path}/..tmp_$fileName');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (e) {
      AppLogger.e('[NoteFileStorage] Failed to delete file $fileName: $e');
    }
  }

  /// Checks if a note file with [fileName] exists.
  Future<bool> noteFileExists(String fileName) async {
    final file = File('${_directory.path}/$fileName');
    return await file.exists();
  }

  /// Returns the last modified timestamp of the given [fileName], or null if the file does not exist.
  Future<DateTime?> getFileLastModified(String fileName) async {
    try {
      final file = File('${_directory.path}/$fileName');
      if (await file.exists()) {
        final stat = await file.stat();
        return stat.modified;
      }
    } catch (e) {
      AppLogger.e(
        '[NoteFileStorage] Failed to get modified time for $fileName: $e',
      );
    }
    return null;
  }
}
