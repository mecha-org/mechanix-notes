import 'dart:io';

class AppPaths {
  /// When set, all app data (database, search index, note files) lives
  /// under this folder instead of the user's home. Used by tests.
  static String? dataRootOverride;

  static String? get home => dataRootOverride ?? Platform.environment['HOME'];
}
