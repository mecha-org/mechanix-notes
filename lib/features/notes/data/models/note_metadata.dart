class NoteMetaData {
  final String id;
  final String title;
  final DateTime updatedAt;
  final String previewText;
  final bool isPinned;

  const NoteMetaData({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.previewText,
    this.isPinned = false,
  });
}
