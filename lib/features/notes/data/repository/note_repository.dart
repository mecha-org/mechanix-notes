import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';

abstract class NoteRepository {
  /// Emits the metadata of all notes (pinned first, then most recently
  /// updated), and again whenever any note is created, updated or deleted.
  Stream<List<NoteMetaData>> watchNotes();
  Future<NoteModel?> getNoteById(String id);
  Future<void> deleteNotes(List<String> ids);
  Future<void> upsertNote(NoteModel note);

  /// Returns the ids of notes matching [query], most relevant first.
  Future<List<String>> searchNoteIds(String query);

  /// Returns the metadata of the notes with the given [ids], in the same
  /// order. Ids with no stored note are skipped.
  Future<List<NoteMetaData>> getNotesMetaData(List<String> ids);
  Future<bool> togglePinNote(String id);
  Future<void> close();
}
