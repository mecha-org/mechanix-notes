class NoteModel {
  String id;
  String title;
  String content;
  DateTime updatedAt;
  String previewText;
  bool isPinned;
  String? fileName;

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    required this.previewText,
    this.isPinned = false,
    this.fileName,
  });
}
