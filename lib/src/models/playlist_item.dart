class PlaylistItem {
  const PlaylistItem({
    required this.id,
    required this.name,
    required this.songIds,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<String> songIds;
  final DateTime updatedAt;

  PlaylistItem copyWith({
    String? id,
    String? name,
    List<String>? songIds,
    DateTime? updatedAt,
  }) {
    return PlaylistItem(
      id: id ?? this.id,
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'songIds': songIds,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PlaylistItem.fromJson(Map<String, dynamic> json) {
    final ids = json['songIds'] as List<dynamic>? ?? const [];
    return PlaylistItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      songIds: ids.map((item) => item.toString()).toList(growable: false),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
