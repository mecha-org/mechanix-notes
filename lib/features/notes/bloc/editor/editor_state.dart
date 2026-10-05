part of 'editor_bloc.dart';

sealed class EditorState extends Equatable {
  const EditorState();

  @override
  List<Object?> get props => [];
}

final class EditorInitial extends EditorState {
  const EditorInitial();
}


final class EditorLoaded extends EditorState {
  final String noteId;
  final String title;
  final Document? quillDocument;
  final bool isContentLoading;
  final bool isSaving;
  final bool isNewNote;
  final bool isDirty;
  final bool isPinned;

  const EditorLoaded({
    required this.noteId,
    required this.title,
    this.quillDocument,
    this.isContentLoading = false,
    this.isSaving = false,
    this.isNewNote = false,
    this.isDirty = false,
    this.isPinned = false,
  });

  EditorLoaded copyWith({
    String? noteId,
    String? title,
    Document? quillDocument,
    bool? isContentLoading,
    bool? isSaving,
    bool? isNewNote,
    bool? isDirty,
    bool? isPinned,
  }) {
    return EditorLoaded(
      noteId: noteId ?? this.noteId,
      title: title ?? this.title,
      quillDocument: quillDocument ?? this.quillDocument,
      isContentLoading: isContentLoading ?? this.isContentLoading,
      isSaving: isSaving ?? this.isSaving,
      isNewNote: isNewNote ?? this.isNewNote,
      isDirty: isDirty ?? this.isDirty,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  @override
  List<Object?> get props => [
    noteId,
    title,
    quillDocument,
    isContentLoading,
    isSaving,
    isNewNote,
    isDirty,
    isPinned,
  ];
}

final class EditorFailure extends EditorState {
  final ErrorCategory error;

  const EditorFailure(this.error);

  @override
  List<Object?> get props => [error];
}

final class EditorSaveSuccess extends EditorState {
  final String noteId;

  const EditorSaveSuccess(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

final class EditorDeleteRequest extends EditorState {
  final String noteId;

  const EditorDeleteRequest(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

final class EditorDiscarded extends EditorState {
  final String? noteId;

  const EditorDiscarded({this.noteId});

  @override
  List<Object?> get props => [noteId];
}
