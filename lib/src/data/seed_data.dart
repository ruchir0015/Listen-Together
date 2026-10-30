import '../models/playlist_item.dart';
import '../models/song_item.dart';

class SeedData {
  static final List<SongItem> library = [
    SongItem(
      id: 'shared-soft-signal',
      title: 'Soft Signal',
      artist: 'Velvet Harbor',
      duration: const Duration(minutes: 3, seconds: 42),
      source: SongSource.shared,
      moodTag: 'night drive',
      senderLabel: 'Your person',
      sharedAt: DateTime(2026, 4, 18, 21, 10),
      downloaded: true,
    ),
    SongItem(
      id: 'shared-window-light',
      title: 'Window Light',
      artist: 'Mira Vale',
      duration: const Duration(minutes: 4, seconds: 8),
      source: SongSource.shared,
      moodTag: 'slow dance',
      senderLabel: 'Your person',
      sharedAt: DateTime(2026, 4, 19, 7, 35),
      downloaded: false,
    ),
    SongItem(
      id: 'local-pocket-sunrise',
      title: 'Pocket Sunrise',
      artist: 'Juniper Lane',
      duration: const Duration(minutes: 2, seconds: 58),
      source: SongSource.local,
      moodTag: 'morning glow',
      downloaded: true,
    ),
    SongItem(
      id: 'local-moonlit-kitchen',
      title: 'Moonlit Kitchen',
      artist: 'Paper Lanterns',
      duration: const Duration(minutes: 3, seconds: 24),
      source: SongSource.local,
      moodTag: 'late snack',
      downloaded: true,
    ),
    SongItem(
      id: 'local-seaside-letter',
      title: 'Seaside Letter',
      artist: 'The Tide Rooms',
      duration: const Duration(minutes: 4, seconds: 12),
      source: SongSource.local,
      moodTag: 'daydream',
      downloaded: false,
    ),
    SongItem(
      id: 'local-little-comet',
      title: 'Little Comet',
      artist: 'Nova Arcade',
      duration: const Duration(minutes: 3, seconds: 16),
      source: SongSource.local,
      moodTag: 'spark',
      downloaded: false,
    ),
    SongItem(
      id: 'shared-paper-stars',
      title: 'Paper Stars',
      artist: 'Sunday Echo',
      duration: const Duration(minutes: 3, seconds: 51),
      source: SongSource.shared,
      moodTag: 'tender',
      senderLabel: 'You',
      sharedAt: DateTime(2026, 4, 19, 22, 4),
      downloaded: true,
    ),
  ];

  static final List<PlaylistItem> playlists = [
    PlaylistItem(
      id: 'playlist-soft-evening',
      name: 'Soft Evening',
      songIds: const [
        'shared-soft-signal',
        'local-moonlit-kitchen',
        'shared-paper-stars',
      ],
      updatedAt: DateTime(2026, 4, 19, 22, 10),
    ),
    PlaylistItem(
      id: 'playlist-morning-check-in',
      name: 'Morning Check-In',
      songIds: const ['local-pocket-sunrise', 'shared-window-light'],
      updatedAt: DateTime(2026, 4, 19, 7, 40),
    ),
  ];
}
