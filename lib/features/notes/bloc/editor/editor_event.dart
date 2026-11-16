part of 'editor_bloc.dart';

sealed class EditorEvent {}

final class EditorInitialised extends EditorEvent {
  final String? noteId;
  final String? noteTitle;
  EditorInitialised({this.noteId, this.noteTitle});
}

sealed class EditorPersistEvent extends EditorEvent {}

final class EditorSaveRequested extends EditorPersistEvent {
  final String content;
  final String? plainText;
  EditorSaveRequested({required this.content, this.plainText});
}

final class EditorAutoSaveRequested extends EditorPersistEvent {
  final String content;
  final String? plainText;
  EditorAutoSaveRequested({required this.content, this.plainText});
}

final class EditorPinToggled extends EditorPersistEvent {}

final class _EditorNoteRenamed extends EditorEvent {
  final NoteRenamed renamed;
  _EditorNoteRenamed(this.renamed);
}
