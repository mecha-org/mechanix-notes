import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';

abstract class NoteRepository {
  /// Emits the metadata of all notes (pinned first, then most recently
  /// updated), and again whenever any note is created, updated or deleted.
  Stream<List<NoteMetaData>> watchNotes();
  Future<NoteModel?> getNoteById(String id);
  Future<void> deleteNotes(List<String> ids);
  Future<String> upsertNote(NoteModel note);
  Stream<NoteRenamed> get noteRenames;

  /// Emits the ids of notes once they have been removed from the index
  /// (deleted in the app or on disk).
  Stream<Set<String>> get noteRemovals;
  Future<List<String>> searchNoteIds(String query);
  Future<List<NoteMetaData>> getNotesMetaData(List<String> ids);
  Future<bool> togglePinNote(String id);
  Future<List<NoteMetaData>> getNotesFromTantivy({int limit = 45});
  Future<int> syncNotesFromDisk();
  Future<void> close();
}

class NoteRenamed {
  final String oldId;
  final String newId;

  const NoteRenamed({required this.oldId, required this.newId});

  @override
  String toString() => 'NoteRenamed($oldId -> $newId)';
}
