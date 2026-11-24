class NoteMetaData {
  final String id;
  final String title;
  final DateTime updatedAt;
  final String previewText;
  final bool isPinned;
  final String? snippet;

  const NoteMetaData({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.previewText,
    this.isPinned = false,
    this.snippet,
  });

  NoteMetaData copyWith({
    String? id,
    String? title,
    DateTime? updatedAt,
    String? previewText,
    bool? isPinned,
    String? snippet,
  }) {
    return NoteMetaData(
      id: id ?? this.id,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
      previewText: previewText ?? this.previewText,
      isPinned: isPinned ?? this.isPinned,
      snippet: snippet ?? this.snippet,
    );
  }
}
