import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pair_connection.dart';
import '../models/playlist_item.dart';
import '../models/song_item.dart';

class LocalSnapshot {
  const LocalSnapshot({
    required this.connection,
    required this.songs,
    required this.playlists,
    required this.ownerSupabaseUrl,
    required this.ownerSupabaseAnonKey,
    required this.activeSupabaseUrl,
    required this.activeSupabaseAnonKey,
  });

  final PairConnection? connection;
  final List<SongItem> songs;
  final List<PlaylistItem> playlists;
  final String? ownerSupabaseUrl;
  final String? ownerSupabaseAnonKey;
  final String? activeSupabaseUrl;
  final String? activeSupabaseAnonKey;
}

class LocalStore {
  static const String _pairKey = 'pair_connection';
  static const String _songsKey = 'songs';
  static const String _playlistsKey = 'playlists';
  static const String _ownerUrlKey = 'owner_supabase_url';
  static const String _ownerKeyKey = 'owner_supabase_anon_key';
  static const String _activeUrlKey = 'active_supabase_url';
  static const String _activeKeyKey = 'active_supabase_anon_key';

  Future<LocalSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalSnapshot(
      connection: _decodeObject(
        prefs.getString(_pairKey),
        PairConnection.fromJson,
      ),
      songs: _decodeList(prefs.getString(_songsKey), SongItem.fromJson),
      playlists: _decodeList(
        prefs.getString(_playlistsKey),
        PlaylistItem.fromJson,
      ),
      ownerSupabaseUrl: prefs.getString(_ownerUrlKey),
      ownerSupabaseAnonKey: prefs.getString(_ownerKeyKey),
      activeSupabaseUrl: prefs.getString(_activeUrlKey),
      activeSupabaseAnonKey: prefs.getString(_activeKeyKey),
    );
  }

  Future<void> savePairConnection(PairConnection connection) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pairKey, jsonEncode(connection.toJson()));
  }

  Future<void> clearPairConnection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pairKey);
  }

  Future<void> saveOwnerSupabaseCredentials(String url, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ownerUrlKey, url);
    await prefs.setString(_ownerKeyKey, key);
  }

  Future<void> saveActiveSupabaseCredentials(String url, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeUrlKey, url);
    await prefs.setString(_activeKeyKey, key);
  }

  Future<void> clearActiveSupabaseCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeUrlKey);
    await prefs.remove(_activeKeyKey);
  }

  Future<void> saveLibrary({
    required List<SongItem> songs,
    required List<PlaylistItem> playlists,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _songsKey,
      jsonEncode(songs.map((song) => song.toJson()).toList(growable: false)),
    );
    await prefs.setString(
      _playlistsKey,
      jsonEncode(
        playlists.map((playlist) => playlist.toJson()).toList(growable: false),
      ),
    );
  }

  T? _decodeObject<T>(
    String? raw,
    T Function(Map<String, dynamic> json) parser,
  ) {
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return parser(decoded);
    } catch (_) {
      return null;
    }
  }

  List<T> _decodeList<T>(
    String? raw,
    T Function(Map<String, dynamic> json) parser,
  ) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(parser)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
