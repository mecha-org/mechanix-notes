part of 'editor_bloc.dart';

sealed class EditorEvent {}

final class EditorInitialised extends EditorEvent {
  final String? noteId;
  final String? noteTitle;
  EditorInitialised({this.noteId, this.noteTitle});
}

final class EditorTitleChanged extends EditorEvent {
  final String title;
  EditorTitleChanged(this.title);
}

final class EditorToolbarToggled extends EditorEvent {
  final EditorToolbar toolbar;
  EditorToolbarToggled(this.toolbar);
}

final class EditorSaveRequested extends EditorEvent {
  final List<dynamic> content;
  final String plainText;
  EditorSaveRequested({required this.content, required this.plainText});
}

final class EditorAutoSaveRequested extends EditorEvent {
  final List<dynamic> content;
  final String plainText;
  EditorAutoSaveRequested({required this.content, required this.plainText});
}

final class EditorPinToggled extends EditorEvent {}
