class SongItem {
  const SongItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.addedBy,
    this.localFilePath,
    this.cachedFilePath,
  });

  final String id;
  final String title;
  final String artist;
  final Duration duration;
  final String addedBy;
  final String? localFilePath;
  final String? cachedFilePath;

  bool isOwner(String myDeviceId) => addedBy == myDeviceId;

  String? get activePath => localFilePath ?? cachedFilePath;

  SongItem copyWith({
    String? id,
    String? title,
    String? artist,
    Duration? duration,
    String? addedBy,
    String? localFilePath,
    String? cachedFilePath,
  }) {
    return SongItem(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      duration: duration ?? this.duration,
      addedBy: addedBy ?? this.addedBy,
      localFilePath: localFilePath ?? this.localFilePath,
      cachedFilePath: cachedFilePath ?? this.cachedFilePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'durationSeconds': duration.inSeconds,
      'addedBy': addedBy,
      'localFilePath': localFilePath,
      'cachedFilePath': cachedFilePath,
    };
  }

  factory SongItem.fromJson(Map<String, dynamic> json) {
    return SongItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      duration: Duration(seconds: json['durationSeconds'] as int? ?? 0),
      addedBy: json['addedBy'] as String? ?? '',
      localFilePath: json['localFilePath'] as String?,
      cachedFilePath: json['cachedFilePath'] as String?,
    );
  }
}
