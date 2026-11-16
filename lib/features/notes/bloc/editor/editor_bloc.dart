import 'dart:async';
import 'dart:io';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_notes/core/exceptions/storage_exception.dart';
import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/core/utils/helper.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:uuid/uuid.dart';

part 'editor_event.dart';
part 'editor_state.dart';

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  final NoteRepository _repository;

  StreamSubscription<NoteRenamed>? _renameSub;

  EditorBloc(this._repository) : super(const EditorInitial()) {
    on<EditorInitialised>(_onInitialised);
    on<EditorPersistEvent>(
      (event, emit) => switch (event) {
        EditorSaveRequested() => _onSaveRequested(event, emit),
        EditorAutoSaveRequested() => _onAutoSaveRequested(event, emit),
        EditorPinToggled() => _onPinToggled(event, emit),
      },
      transformer: sequential(),
    );
    // Not queued: a rename must apply even while a save is in flight.
    on<_EditorNoteRenamed>(_onNoteRenamed);
    _renameSub = _repository.noteRenames.listen(
      (renamed) => add(_EditorNoteRenamed(renamed)),
    );
  }

  @override
  Future<void> close() async {
    await _renameSub?.cancel();
    return super.close();
  }

  void _onNoteRenamed(_EditorNoteRenamed event, Emitter<EditorState> emit) {
    final current = state;
    if (current is EditorLoaded && current.noteId == event.renamed.oldId) {
      AppLogger.i('EditorBloc: Following rename ${event.renamed}');
      emit(current.copyWith(noteId: event.renamed.newId));
    }
  }

  Future<String> _persist(NoteModel note) async {
    try {
      return await _repository.upsertNote(note);
    } on NoteFileMissingException catch (e) {
      AppLogger.i('EditorBloc: $e; re-creating note');
      note.fileName = null;
      return await _repository.upsertNote(note);
    }
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

        final initialContent = note.content.trim().isEmpty
            ? '# '
            : note.content;

        AppLogger.i('EditorBloc: Content ready for ${event.noteId}');
        emit(
          EditorLoaded(
            noteId: note.fileName ?? note.id,
            title: event.noteTitle ?? note.title,
            markdownContent: initialContent,
            lastSavedContent: initialContent,
            lastSavedTitle: event.noteTitle ?? note.title,
            lastSavedIsPinned: note.isPinned,
            createdAt: note.createdAt,
            isContentLoading: false,
            isNewNote: false,
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
            lastSavedContent: '# ',
            lastSavedTitle: '',
            lastSavedIsPinned: false,
            createdAt: DateTime.now(),
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
      final markdown = event.content;
      final plainText = (event.plainText ?? markdownToPlainText(markdown))
          .trim();

      NoteModel? existing;
      if (current.lastSavedContent.isEmpty) {
        existing = await _repository.getNoteById(current.noteId);
      }

      final note = buildNote(
        current: current,
        content: markdown,
        plainText: plainText,
        existing: existing,
      );

      final isEmpty = note.title.trim().isEmpty && plainText.isEmpty;

      if (isEmpty) {
        if (current.isNewNote) {
          AppLogger.i('EditorBloc: Discarding empty new note');
          emit(const EditorDiscarded());
        } else {
          AppLogger.i('EditorBloc: Deleting existing note because it is empty');
          emit(EditorDeleteRequest(current.noteId));
        }
        return;
      }

      // Check if content is unchanged using in-memory baseline
      if (!current.isNewNote) {
        final lastSavedContent = existing != null
            ? existing.content
            : current.lastSavedContent;
        final lastSavedTitle = existing != null
            ? existing.title
            : current.lastSavedTitle;
        final lastSavedIsPinned = existing != null
            ? existing.isPinned
            : current.lastSavedIsPinned;

        final isContentUnchanged = lastSavedContent == markdown;
        final isTitleUnchanged =
            lastSavedTitle == note.title ||
            (isContentUnchanged && lastSavedTitle == current.title);
        final isPinUnchanged = lastSavedIsPinned == note.isPinned;

        if (isContentUnchanged && isTitleUnchanged && isPinUnchanged) {
          AppLogger.i('EditorBloc: Discarding unchanged edit');
          emit(
            EditorDiscarded(noteId: current.isDirty ? current.noteId : null),
          );
          return;
        }
      }

      emit(current.copyWith(isSaving: true, title: note.title));

      final savedId = await _persist(note);

      AppLogger.i('EditorBloc: Manual save success for $savedId');
      emit(EditorSaveSuccess(savedId));
    } on DbFullException catch (e) {
      AppLogger.e('EditorBloc: Manual save failed due to full database: $e');
      emit(const EditorFailure(ErrorCategory.storageFull));
    } on FileSystemException catch (e) {
      if (e.osError?.errorCode == 28 || e.message.contains('No space left')) {
        emit(const EditorFailure(ErrorCategory.storageFull));
      } else {
        AppLogger.e('EditorBloc: Manual save failed: $e');
        emit(const EditorFailure(ErrorCategory.failedToSaveNote));
      }
    } catch (e) {
      AppLogger.e('EditorBloc: Manual save failed: $e');
      emit(const EditorFailure(ErrorCategory.failedToSaveNote));
    }
  }

  (String title, String previewText) _extractTitleAndPreview(
    String currentTitle,
    String plainText, {
    String? content,
  }) {
    final trimmed = plainText.trim();
    if (trimmed.isEmpty) {
      final hasNoContent =
          content == null || content.trim().isEmpty || content.trim() == '#';
      return (hasNoContent && currentTitle.isEmpty ? '' : currentTitle, '');
    }

    if (content != null && content.isNotEmpty) {
      final trimmedContent = content.trimLeft();
      final firstContentLine = trimmedContent.split('\n').first.trim();
      final isH1 =
          firstContentLine.startsWith('#') &&
          !firstContentLine.startsWith('##');
      if (isH1) {
        return extractTitleAndPreviewFromMarkdown(
          content,
          fallbackTitle: currentTitle,
        );
      }
    }

    return extractTitleAndPreviewFromMarkdown(
      plainText,
      fallbackTitle: currentTitle,
    );
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
      content: content,
    );

    return NoteModel(
      id: current.noteId,
      title: title,
      content: content,
      previewText: previewText,
      createdAt: existing?.createdAt ?? current.createdAt ?? now,
      updatedAt: now,
      isPinned: current.isPinned,
      fileName: current.isNewNote ? null : current.noteId,
    );
  }

  Future<void> _onAutoSaveRequested(
    EditorAutoSaveRequested event,
    Emitter<EditorState> emit,
  ) async {
    final current = state;
    if (current is! EditorLoaded) return;

    try {
      final markdown = event.content;
      final plainText = (event.plainText ?? markdownToPlainText(markdown))
          .trim();

      NoteModel? existing;
      if (current.lastSavedContent.isEmpty) {
        existing = await _repository.getNoteById(current.noteId);
      }

      final note = buildNote(
        current: current,
        content: markdown,
        plainText: plainText,
        existing: existing,
      );

      // Don't auto-save if nothing changed
      if (!current.isNewNote) {
        final lastSavedContent = existing != null
            ? existing.content
            : current.lastSavedContent;
        final lastSavedTitle = existing != null
            ? existing.title
            : current.lastSavedTitle;
        final lastSavedIsPinned = existing != null
            ? existing.isPinned
            : current.lastSavedIsPinned;

        final isContentUnchanged = lastSavedContent == markdown;
        final isTitleUnchanged =
            lastSavedTitle == note.title ||
            (isContentUnchanged && lastSavedTitle == current.title);
        final isPinUnchanged = lastSavedIsPinned == note.isPinned;

        if (isContentUnchanged && isTitleUnchanged && isPinUnchanged) {
          return;
        }
      }

      // Don't auto-save if new and empty
      if (current.isNewNote && note.title.trim().isEmpty && plainText.isEmpty) {
        return;
      }

      final savedId = await _persist(note);

      AppLogger.i('EditorBloc: Auto-save success for $savedId');
      final latestState = state;
      if (latestState is! EditorLoaded) return;

      emit(
        latestState.copyWith(
          noteId: savedId,
          title: note.title,
          lastSavedContent: markdown,
          lastSavedTitle: note.title,
          lastSavedIsPinned: latestState.isPinned,
          createdAt: note.createdAt,
          isDirty: true,
          isNewNote: false,
        ),
      );
    } on DbFullException catch (e) {
      AppLogger.e('EditorBloc: Auto-save failed due to full database: $e');
      emit(const EditorFailure(ErrorCategory.storageFull));
    } on FileSystemException catch (e) {
      if (e.osError?.errorCode == 28 || e.message.contains('No space left')) {
        emit(const EditorFailure(ErrorCategory.storageFull));
      } else {
        AppLogger.e('EditorBloc: Auto-save failed: $e');
      }
    } catch (e) {
      AppLogger.e('EditorBloc: Auto-save failed: $e');
    }
  }

  Future<void> _onPinToggled(
    EditorPinToggled event,
    Emitter<EditorState> emit,
  ) async {
    final current = state;
    if (current is! EditorLoaded) return;
    final nextPinned = !current.isPinned;

    emit(
      current.copyWith(
        isPinned: nextPinned,
        lastSavedIsPinned: nextPinned,
        isDirty: true,
      ),
    );

    if (!current.isNewNote) {
      await _repository.togglePinNote(current.noteId);
    }
  }
}
