import 'song_item.dart';

class PlaybackSession {
  const PlaybackSession({
    required this.pairId,
    required this.queue,
    required this.currentIndex,
    required this.isPlaying,
    required this.positionSeconds,
    required this.lastUpdatedBy,
    required this.lastUpdatedAt,
  });

  final String pairId;
  final List<SongItem> queue;
  final int currentIndex;
  final bool isPlaying;
  final int positionSeconds;
  final String lastUpdatedBy;
  final DateTime lastUpdatedAt;

  SongItem? get currentSong {
    if (queue.isEmpty || currentIndex < 0 || currentIndex >= queue.length) {
      return null;
    }
    return queue[currentIndex];
  }

  PlaybackSession copyWith({
    String? pairId,
    List<SongItem>? queue,
    int? currentIndex,
    bool? isPlaying,
    int? positionSeconds,
    String? lastUpdatedBy,
    DateTime? lastUpdatedAt,
  }) {
    return PlaybackSession(
      pairId: pairId ?? this.pairId,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pair_id': pairId,
      'queue': queue.map((song) => song.toJson()).toList(),
      'current_index': currentIndex,
      'is_playing': isPlaying,
      'position_seconds': positionSeconds,
      'last_updated_by': lastUpdatedBy,
      'last_updated_at': lastUpdatedAt.toIso8601String(),
    };
  }

  factory PlaybackSession.fromJson(Map<String, dynamic> json) {
    final queueRaw = json['queue'] as List<dynamic>? ?? [];
    final queue = queueRaw
        .map((item) => SongItem.fromJson(item as Map<String, dynamic>))
        .toList();

    return PlaybackSession(
      pairId: json['pair_id'] as String? ?? '',
      queue: queue,
      currentIndex: json['current_index'] as int? ?? 0,
      isPlaying: json['is_playing'] as bool? ?? false,
      positionSeconds: json['position_seconds'] as int? ?? 0,
      lastUpdatedBy: json['last_updated_by'] as String? ?? '',
      lastUpdatedAt: DateTime.tryParse(json['last_updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
