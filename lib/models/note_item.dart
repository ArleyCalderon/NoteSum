class NoteItem {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;

  const NoteItem({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    return NoteItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}