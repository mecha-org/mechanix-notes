import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/core/utils/constants.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/core/utils/helper.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';

part 'editor_event.dart';
part 'editor_state.dart';

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  final NoteRepository _repository;

  EditorBloc(this._repository) : super(const EditorInitial()) {
    on<EditorInitialised>(_onInitialised);
    on<EditorSaveRequested>(_onSaveRequested);
    on<EditorAutoSaveRequested>(_onAutoSaveRequested);
    on<EditorPinToggled>(_onPinToggled);
    on<EditorCheckExternalModification>(_onCheckExternalModification);
    on<EditorReloadContentAccepted>(_onReloadContentAccepted);
  }

  // Event Handlers
  Future<void> _onInitialised(
    EditorInitialised event,
    Emitter<EditorState> emit,
  ) async {
    try {
      final isEditMode = event.noteId != null;

      if (isEditMode) {
        emit(
          EditorLoaded(
            noteId: event.noteId!,
            title: event.noteTitle ?? '',
            isContentLoading: true,
            isNewNote: false,
          ),
        );

        final note = await _repository.getNoteById(event.noteId!);

        if (note == null) {
          AppLogger.e('EditorBloc: Note not found for id ${event.noteId}');
          emit(const EditorFailure(ErrorCategory.noteNotFound));
          return;
        }

        final isFileMissing = note.isFileMissing;
        final initialContent = isFileMissing || note.content.trim().isEmpty
            ? '# '
            : note.content;

        DateTime? lastModified;
        if (!isFileMissing) {
          try {
            lastModified = await _repository.getNoteFileLastModified(note.id);
          } catch (_) {
            lastModified = null;
          }
        }

        AppLogger.i(
          'EditorBloc: Content ready for ${event.noteId} (missing on disk: $isFileMissing)',
        );
        emit(
          EditorLoaded(
            noteId: note.id,
            title: isFileMissing ? '' : (event.noteTitle ?? note.title),
            markdownContent: initialContent,
            isContentLoading: false,
            isNewNote: isFileMissing,
            isFileMissing: isFileMissing,
            fileLastModified: lastModified,
            isPinned: note.isPinned,
          ),
        );
      } else {
        final newId = const Uuid().v4();
        AppLogger.i('EditorBloc: Create mode — generated id $newId');

        emit(
          EditorLoaded(
            noteId: newId,
            title: '',
            markdownContent: '# ',
            isContentLoading: false,
            isNewNote: true,
          ),
        );
      }
    } catch (e) {
      AppLogger.e('EditorBloc: Failed to load note: $e');
      emit(const EditorFailure(ErrorCategory.somethingWentWrong));
    }
  }

  Future<void> _onSaveRequested(
    EditorSaveRequested event,
    Emitter<EditorState> emit,
  ) async {
    final current = state;
    if (current is! EditorLoaded) return;

    try {
      final existing = await _repository.getNoteById(current.noteId);
      final markdown = event.content;
      final plainText = (event.plainText ?? markdownToPlainText(markdown))
          .trim();

      final isEmpty = current.title.trim().isEmpty && plainText.isEmpty;

      if (isEmpty) {
        if (current.isNewNote && !current.isFileMissing) {
          AppLogger.i('EditorBloc: Discarding empty new note');
          emit(const EditorDiscarded());
        } else {
          AppLogger.i('EditorBloc: Deleting existing note because it is empty');
          emit(EditorDeleteRequest(current.noteId));
        }
        return;
      }

      final note = buildNote(
        current: current,
        content: markdown,
        plainText: plainText,
        existing: existing,
      );

      // Check if content is unchanged
      if (existing != null && !current.isFileMissing) {
        if (existing.title == note.title &&
            existing.content == markdown &&
            existing.isPinned == note.isPinned) {
          AppLogger.i('EditorBloc: Discarding unchanged edit');
          emit(
            EditorDiscarded(noteId: current.isDirty ? current.noteId : null),
          );
          return;
        }
      }

      emit(current.copyWith(isSaving: true, title: note.title));

      await _repository.upsertNote(note);

      AppLogger.i('EditorBloc: Manual save success for ${current.noteId}');
      emit(EditorSaveSuccess(current.noteId));
    } on DbFullException catch (e) {
      AppLogger.e('EditorBloc: Manual save failed due to full database: $e');
      emit(const EditorFailure(ErrorCategory.storageFull));
    } catch (e) {
      AppLogger.e('EditorBloc: Manual save failed: $e');
      emit(const EditorFailure(ErrorCategory.failedToSaveNote));
    }
  }

  (String title, String previewText) _extractTitleAndPreview(
    String currentTitle,
    String plainText,
  ) {
    final trimmed = plainText.trim();
    if (trimmed.isEmpty) {
      return (currentTitle, '');
    }

    final lines = plainText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.length > 1) {
      final title = lines.first;
      final bodyText = lines.skip(1).join(' ');
      final preview = bodyText.length > Constants.notePreviewTextMaxLength
          ? bodyText.substring(0, Constants.notePreviewTextMaxLength)
          : bodyText;
      return (title, preview);
    }

    // Only 1 line of text:
    final singleLine = lines.first;
    if (currentTitle.isNotEmpty && currentTitle != singleLine) {
      final preview = singleLine.length > Constants.notePreviewTextMaxLength
          ? singleLine.substring(0, Constants.notePreviewTextMaxLength)
          : singleLine;
      return (currentTitle, preview);
    }

    final preview = singleLine.length > Constants.notePreviewTextMaxLength
        ? singleLine.substring(0, Constants.notePreviewTextMaxLength)
        : singleLine;
    return (singleLine, preview);
  }

  NoteModel buildNote({
    required EditorLoaded current,
    required String content,
    required String plainText,
    NoteModel? existing,
  }) {
    final now = DateTime.now();

    final (title, previewText) = _extractTitleAndPreview(
      current.title,
      plainText,
    );

    return NoteModel(
      id: current.noteId,
      title: title,
      content: content,
      plainText: plainText,
      previewText: previewText,
      height: _estimateHeight(plainText),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      isPinned: current.isPinned,
    );
  }

  Future<void> _onAutoSaveRequested(
    EditorAutoSaveRequested event,
    Emitter<EditorState> emit,
  ) async {
    final current = state;
    if (current is! EditorLoaded) return;

    try {
      final existing = await _repository.getNoteById(current.noteId);
      final markdown = event.content;
      final plainText = (event.plainText ?? markdownToPlainText(markdown))
          .trim();

      final note = buildNote(
        current: current,
        content: markdown,
        plainText: plainText,
        existing: existing,
      );

      // Don't auto-save if nothing changed
      if (existing != null &&
          existing.title == note.title &&
          existing.content == markdown &&
          existing.isPinned == note.isPinned) {
        return;
      }

      // Don't auto-save if new/missing and empty
      if ((current.isNewNote || current.isFileMissing) &&
          note.title.trim().isEmpty &&
          plainText.isEmpty) {
        return;
      }

      await _repository.upsertNote(note);
      DateTime? newModified;
      try {
        newModified = await _repository.getNoteFileLastModified(current.noteId);
      } catch (_) {
        newModified = null;
      }

      AppLogger.i('EditorBloc: Auto-save success for ${current.noteId}');
      emit(
        current.copyWith(
          title: note.title,
          isDirty: true,
          isNewNote: false,
          isFileMissing: false,
          fileLastModified: newModified,
        ),
      );
    } on DbFullException catch (e) {
      AppLogger.e('EditorBloc: Auto-save failed due to full database: $e');
      emit(const EditorFailure(ErrorCategory.storageFull));
    } catch (e) {
      AppLogger.e('EditorBloc: Auto-save failed: $e');
    }
  }

  Future<void> _onCheckExternalModification(
    EditorCheckExternalModification event,
    Emitter<EditorState> emit,
  ) async {
    final current = state;
    if (current is! EditorLoaded) return;
    if (current.isNewNote || current.isFileMissing) return;

    try {
      final diskModified = await _repository.getNoteFileLastModified(
        current.noteId,
      );
      if (diskModified == null) return;

      if (current.fileLastModified != null &&
          diskModified.isAfter(current.fileLastModified!)) {
        final diskNote = await _repository.getNoteById(current.noteId);
        if (diskNote != null &&
            !diskNote.isFileMissing &&
            diskNote.content != current.markdownContent) {
          AppLogger.i(
            'EditorBloc: External modification detected on disk for ${current.noteId}',
          );
          emit(
            EditorExternalModificationDetected(
              noteId: current.noteId,
              title: diskNote.title.isNotEmpty ? diskNote.title : current.title,
              markdownContent: current.markdownContent,
              isContentLoading: current.isContentLoading,
              isSaving: current.isSaving,
              isNewNote: current.isNewNote,
              isDirty: current.isDirty,
              isPinned: current.isPinned,
              isFileMissing: current.isFileMissing,
              fileLastModified: diskModified,
              externalContent: diskNote.content,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.e('EditorBloc: Failed to check external modification: $e');
    }
  }

  Future<void> _onReloadContentAccepted(
    EditorReloadContentAccepted event,
    Emitter<EditorState> emit,
  ) async {
    final current = state;
    if (current is! EditorLoaded) return;

    final diskModified = await _repository.getNoteFileLastModified(
      current.noteId,
    );
    final diskNote = await _repository.getNoteById(current.noteId);

    AppLogger.i('EditorBloc: Reloaded external content for ${current.noteId}');
    emit(
      EditorLoaded(
        noteId: current.noteId,
        title: diskNote?.title ?? current.title,
        markdownContent: event.content,
        isContentLoading: false,
        isSaving: false,
        isNewNote: false,
        isDirty: false,
        isPinned: diskNote?.isPinned ?? current.isPinned,
        isFileMissing: false,
        fileLastModified: diskModified ?? current.fileLastModified,
      ),
    );
  }

  Future<void> _onPinToggled(
    EditorPinToggled event,
    Emitter<EditorState> emit,
  ) async {
    final current = state;
    if (current is! EditorLoaded) return;
    final nextPinned = !current.isPinned;
    emit(current.copyWith(isPinned: nextPinned, isDirty: true));

    if (!current.isNewNote) {
      await _repository.togglePinNote(current.noteId);
    }
  }

  // Helper

  double _estimateHeight(String plainText) {
    return estimateNoteHeight(plainText);
  }
}
