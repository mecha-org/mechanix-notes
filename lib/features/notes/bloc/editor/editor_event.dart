part of 'editor_bloc.dart';

sealed class EditorEvent {
  const EditorEvent();
}

final class EditorInitialised extends EditorEvent {
  final String? noteId;
  final String? noteTitle;
  EditorInitialised({this.noteId, this.noteTitle});
}

final class EditorSaveRequested extends EditorEvent {
  final String content;
  final String? plainText;
  EditorSaveRequested({required this.content, this.plainText});
}

final class EditorAutoSaveRequested extends EditorEvent {
  final String content;
  final String? plainText;
  EditorAutoSaveRequested({required this.content, this.plainText});
}

final class EditorPinToggled extends EditorEvent {}

final class EditorCheckExternalModification extends EditorEvent {
  const EditorCheckExternalModification();
}

final class EditorReloadContentAccepted extends EditorEvent {
  final String content;
  EditorReloadContentAccepted({required this.content});
}
