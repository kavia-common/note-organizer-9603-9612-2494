enum SyncStatus {
  clean,
  dirty,
  syncing,
  failed,
}

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
    required this.syncStatus,
    required this.lastSyncedAt,
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final SyncStatus syncStatus;
  final DateTime? lastSyncedAt;

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
    DateTime? lastSyncedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
