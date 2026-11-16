class DatabaseLockedException implements Exception {
  final String message;

  DatabaseLockedException([
    this.message = 'Notes app is already open in another instance.',
  ]);

  @override
  String toString() => message;
}

class StorageFullException implements Exception {
  final String message;
  final int? errorCode;

  StorageFullException([this.message = 'Storage is full.', this.errorCode]);

  @override
  String toString() => message;
}

/// Backwards-compatibility aliases
typedef ObjectBoxException = DatabaseLockedException;
typedef DbFullException = StorageFullException;

class NoteFileMissingException implements Exception {
  final String fileName;

  NoteFileMissingException(this.fileName);

  @override
  String toString() => 'Note file not found: $fileName';
}
