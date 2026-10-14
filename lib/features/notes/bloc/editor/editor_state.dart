part of 'editor_bloc.dart';

sealed class EditorState extends Equatable {
  const EditorState();

  @override
  List<Object?> get props => [];
}

final class EditorInitial extends EditorState {
  const EditorInitial();
}

base class EditorLoaded extends EditorState {
  final String noteId;
  final String title;
  final String markdownContent;
  final bool isContentLoading;
  final bool isSaving;
  final bool isNewNote;
  final bool isDirty;
  final bool isPinned;
  final bool isFileMissing;
  final DateTime? fileLastModified;

  const EditorLoaded({
    required this.noteId,
    required this.title,
    this.markdownContent = '',
    this.isContentLoading = false,
    this.isSaving = false,
    this.isNewNote = false,
    this.isDirty = false,
    this.isPinned = false,
    this.isFileMissing = false,
    this.fileLastModified,
  });

  EditorLoaded copyWith({
    String? noteId,
    String? title,
    String? markdownContent,
    bool? isContentLoading,
    bool? isSaving,
    bool? isNewNote,
    bool? isDirty,
    bool? isPinned,
    bool? isFileMissing,
    DateTime? fileLastModified,
  }) {
    return EditorLoaded(
      noteId: noteId ?? this.noteId,
      title: title ?? this.title,
      markdownContent: markdownContent ?? this.markdownContent,
      isContentLoading: isContentLoading ?? this.isContentLoading,
      isSaving: isSaving ?? this.isSaving,
      isNewNote: isNewNote ?? this.isNewNote,
      isDirty: isDirty ?? this.isDirty,
      isPinned: isPinned ?? this.isPinned,
      isFileMissing: isFileMissing ?? this.isFileMissing,
      fileLastModified: fileLastModified ?? this.fileLastModified,
    );
  }

  @override
  List<Object?> get props => [
    noteId,
    title,
    markdownContent,
    isContentLoading,
    isSaving,
    isNewNote,
    isDirty,
    isPinned,
    isFileMissing,
    fileLastModified,
  ];
}

final class EditorExternalModificationDetected extends EditorLoaded {
  final String externalContent;

  const EditorExternalModificationDetected({
    required super.noteId,
    required super.title,
    super.markdownContent,
    super.isContentLoading,
    super.isSaving,
    super.isNewNote,
    super.isDirty,
    super.isPinned,
    super.isFileMissing,
    super.fileLastModified,
    required this.externalContent,
  });

  @override
  List<Object?> get props => [...super.props, externalContent];
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
