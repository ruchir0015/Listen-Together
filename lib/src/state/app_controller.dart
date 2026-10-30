import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pair_connection.dart';
import '../models/playlist_item.dart';
import '../models/song_item.dart';
import '../models/playback_session.dart';
import '../services/local_store.dart';
import '../services/playback_service.dart';
import '../services/supabase_service.dart';
import '../services/webrtc_service.dart';

class PairingToken {
  const PairingToken({
    required this.pairId,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  final String pairId;
  final String supabaseUrl;
  final String supabaseAnonKey;

  String encode() {
    final raw = '$pairId|$supabaseUrl|$supabaseAnonKey';
    return base64Url.encode(utf8.encode(raw));
  }

  factory PairingToken.decode(String token) {
    try {
      final decoded = utf8.decode(base64Url.decode(token));
      final parts = decoded.split('|');
      if (parts.length >= 3) {
        return PairingToken(
          pairId: parts[0],
          supabaseUrl: parts[1],
          supabaseAnonKey: parts[2],
        );
      }
    } catch (_) {}
    throw const FormatException('Invalid pairing token');
  }
}

class AppController extends ChangeNotifier {
  AppController(
    this._store, {
    PlaybackService? playbackService,
    SupabaseService? supabaseService,
    WebRTCService? Function(String, String, SupabaseService)? webrtcServiceBuilder,
  }) : _playbackService = playbackService ?? JustAudioPlaybackService(),
       _supabaseServiceInstance = supabaseService,
       _webrtcServiceBuilder = webrtcServiceBuilder {
    _bindPlayback();
  }

  static const List<String> _audioExtensions = [
    'mp3',
    'm4a',
    'aac',
    'wav',
    'flac',
    'ogg',
    'opus',
  ];

  final LocalStore _store;
  final PlaybackService _playbackService;
  final Random _random = Random();
  final WebRTCService? Function(String, String, SupabaseService)? _webrtcServiceBuilder;

  SupabaseService? _supabaseServiceInstance;
  SupabaseService get supabaseService => _supabaseServiceInstance ??= SupabaseService();
  SupabaseService get _supabaseService => supabaseService;
  WebRTCService? _webrtcService;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<void>? _completedSubscription;
  StreamSubscription<PlaybackSession>? _sessionSubscription;

  bool _isReady = false;
  bool _isImporting = false;
  PairConnection? _pairConnection;
  bool _showConnectionCelebration = false;
  String? _generatedPairCode;

  List<SongItem> _localLibrarySongs = const [];
  List<PlaylistItem> _playlists = const [];
  PlaybackSession? _playbackSession; // paired: from Supabase stream
  PlaybackSession? _localSession;    // solo: local-only, never synced

  String? _ownerUrl;
  String? _ownerKey;
  String? _activeUrl;
  String? _activeKey;

  bool _isPlaying = false;
  double _elapsedSeconds = 0;
  bool _isBuffering = false;
  String? _loadedSongId;
  Timer? _positionSyncTimer;

  // --- Presence (heartbeat) ---
  bool _partnerOnline = false;
  String? _partnerDeviceId;
  DateTime? _lastPartnerHeartbeat;
  Timer? _heartbeatTimer;
  Timer? _partnerWatchdogTimer;
  RealtimeChannel? _presenceChannel;
  RealtimeChannel? _sessionSyncChannel;

  bool get isReady => _isReady;
  bool get isImporting => _isImporting;
  bool get isPaired => _pairConnection != null;
  PairConnection? get pairConnection => _pairConnection;
  bool get showConnectionCelebration => _showConnectionCelebration;
  String? get generatedPairCode => _generatedPairCode;
  String get inviteLink => _generatedPairCode == null
      ? ''
      : 'musiclisten://pair/$_generatedPairCode';

  List<SongItem> get localSongs => List.unmodifiable(_localLibrarySongs);
  List<PlaylistItem> get playlists => List.unmodifiable(_playlists);
  PlaybackSession? get playbackSession => isPaired ? _playbackSession : _localSession;

  /// Active session: paired Supabase session when connected, local session otherwise.
  PlaybackSession? get _activeSession => isPaired ? _playbackSession : _localSession;

  List<SongItem> get queue => _activeSession?.queue ?? const [];
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get partnerOnline => _partnerOnline;
  String? get partnerDeviceId => _partnerDeviceId;

  String? get ownerSupabaseUrl => _ownerUrl;
  String? get ownerSupabaseAnonKey => _ownerKey;
  String? get activeSupabaseUrl => _activeUrl ?? _ownerUrl;
  String? get activeSupabaseAnonKey => _activeKey ?? _ownerKey;

  bool get hasSupabaseCredentials =>
      _ownerUrl != null && _ownerUrl!.isNotEmpty && _ownerKey != null && _ownerKey!.isNotEmpty;

  WebRTCConnState get webRTCState => _webrtcService?.connectionState ?? WebRTCConnState.disconnected;
  bool get isStreaming => _webrtcService?.isTransferring ?? false;
  double get streamProgress => _webrtcService?.transferProgress ?? 0.0;
  String get streamStatus => _webrtcService?.transferStatus ?? '';

  String get pairIdLabel => _pairConnection?.pairId ?? 'UNPAIRED';
  String get deviceIdLabel => _pairConnection?.deviceId ?? 'device-pending';

  SongItem? get currentSong => _activeSession?.currentSong;

  Duration get elapsed => Duration(seconds: _elapsedSeconds.round());

  double get progressFraction {
    final track = currentSong;
    if (track == null || track.duration.inSeconds == 0) {
      return 0;
    }
    return (_elapsedSeconds / track.duration.inSeconds).clamp(0.0, 1.0);
  }

  String get presenceLine {
    final track = currentSong;
    if (track == null) {
      return 'Shared queue is empty. Go to "Add Songs" tab to fill it.';
    }
    if (_isBuffering) {
      return 'Syncing file from partner...';
    }
    if (_isPlaying) {
      return 'Synchronized Listening: ${track.title}';
    }
    return 'Paused: ${track.title}';
  }

  Future<void> load() async {
    final snapshot = await _store.load();
    _pairConnection = snapshot.connection;
    _localLibrarySongs = snapshot.songs;
    _playlists = snapshot.playlists;
    _ownerUrl = snapshot.ownerSupabaseUrl;
    _ownerKey = snapshot.ownerSupabaseAnonKey;
    _activeUrl = snapshot.activeSupabaseUrl;
    _activeKey = snapshot.activeSupabaseAnonKey;

    if (hasSupabaseCredentials) {
      final activeUrl = _activeUrl ?? _ownerUrl!;
      final activeKey = _activeKey ?? _ownerKey!;
      supabaseService.initCredentials(activeUrl, activeKey);

      if (_pairConnection != null) {
        _initSyncAndWebRTC();
      }
    }

    _isReady = true;
    notifyListeners();
  }

  void _initSyncAndWebRTC() {
    try {
      final conn = _pairConnection!;
      if (!supabaseService.isInitialized) return;

      if (_webrtcServiceBuilder != null) {
        _webrtcService = _webrtcServiceBuilder!(conn.pairId, conn.deviceId, supabaseService);
      } else {
        _webrtcService = WebRTCService(
          pairId: conn.pairId,
          myDeviceId: conn.deviceId,
          supabaseService: supabaseService,
        );
      }

      _webrtcService!.onSongFileReceived = _handleSongFileReceived;
      _webrtcService!.onLocalFileRequested = _handleLocalFileRequested;
      _webrtcService!.addListener(notifyListeners);

      _sessionSubscription?.cancel();
      _sessionSubscription = supabaseService.streamSession(conn.pairId).listen(_handleSessionUpdate);

      // Create session sync broadcast channel
      if (_sessionSyncChannel != null) {
        supabaseService.removeChannel(_sessionSyncChannel!);
      }
      _sessionSyncChannel = supabaseService.createSessionSyncChannel(
        conn.pairId,
        conn.deviceId,
        (session) {
          _handleSessionUpdate(session);
        },
      );

      // Start heartbeat presence so both devices know who is in the room.
      _startPresence(conn.pairId, conn.deviceId);
    } catch (e) {
      print('Failed to initialize Sync/WebRTC: $e');
    }
  }

  Future<void> saveSupabaseCredentials(String url, String key) async {
    _ownerUrl = url;
    _ownerKey = key;
    await _store.saveOwnerSupabaseCredentials(url, key);

    if (_pairConnection == null) {
      _activeUrl = url;
      _activeKey = key;
      await _store.saveActiveSupabaseCredentials(url, key);
      supabaseService.initCredentials(url, key);
    }
    notifyListeners();
  }

  Future<void> updateCredentials(String url, String key) async {
    await saveSupabaseCredentials(url, key);
    if (_pairConnection != null) {
      _initSyncAndWebRTC();
    }
  }

  String generatePairingCode() {
    const moods = ['MOON', 'SOFT', 'TULIP', 'COZY', 'STARS', 'MINT'];
    final pairId = '${moods[_random.nextInt(moods.length)]}-${1000 + _random.nextInt(9000)}';

    final token = PairingToken(
      pairId: pairId,
      supabaseUrl: _ownerUrl ?? '',
      supabaseAnonKey: _ownerKey ?? '',
    ).encode();

    _generatedPairCode = token;
    notifyListeners();
    return _generatedPairCode!;
  }

  Future<void> connectForever(String rawToken) async {
    final cleanToken = rawToken.trim();
    if (cleanToken.isEmpty) return;

    try {
      final token = PairingToken.decode(cleanToken);
      final deviceId = 'device-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

      _pairConnection = PairConnection(
        pairId: token.pairId,
        deviceId: deviceId,
        createdAt: DateTime.now(),
      );

      _activeUrl = token.supabaseUrl;
      _activeKey = token.supabaseAnonKey;
      await _store.saveActiveSupabaseCredentials(token.supabaseUrl, token.supabaseAnonKey);

      supabaseService.initCredentials(token.supabaseUrl, token.supabaseAnonKey);
      await _store.savePairConnection(_pairConnection!);

      _supabaseService.getSession(token.pairId).then((existingSession) {
        if (existingSession == null) {
          final newSession = PlaybackSession(
            pairId: token.pairId,
            queue: const [],
            currentIndex: 0,
            isPlaying: false,
            positionSeconds: 0,
            lastUpdatedBy: deviceId,
            lastUpdatedAt: DateTime.now(),
          );
          _supabaseService.updateSession(newSession);
        }
      }).catchError((e) {
        print('Supabase session initialization error: $e');
      });

      _showConnectionCelebration = true;
      _initSyncAndWebRTC();
      notifyListeners();
    } catch (e) {
      // Graceful fallback to legacy pairing code (using user's own project)
      final normalized = rawToken
          .trim()
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');

      if (normalized.isEmpty) return;

      final deviceId = 'device-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
      _pairConnection = PairConnection(
        pairId: normalized,
        deviceId: deviceId,
        createdAt: DateTime.now(),
      );

      _activeUrl = _ownerUrl;
      _activeKey = _ownerKey;
      if (_ownerUrl != null && _ownerKey != null) {
        await _store.saveActiveSupabaseCredentials(_ownerUrl!, _ownerKey!);
        supabaseService.initCredentials(_ownerUrl!, _ownerKey!);
      }

      await _store.savePairConnection(_pairConnection!);

      _showConnectionCelebration = true;
      _initSyncAndWebRTC();
      notifyListeners();
    }
  }

  Future<void> resetPairing() async {
    _stopPositionSyncTimer();
    _stopPresence();
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    _webrtcService?.dispose();
    _webrtcService = null;
    _playbackSession = null;
    _pairConnection = null;
    _generatedPairCode = null;
    _showConnectionCelebration = false;
    _isPlaying = false;
    _loadedSongId = null;
    await _playbackService.stop();
    await _store.clearPairConnection();

    _activeUrl = null;
    _activeKey = null;
    await _store.clearActiveSupabaseCredentials();

    if (_ownerUrl != null && _ownerKey != null) {
      supabaseService.initCredentials(_ownerUrl!, _ownerKey!);
    }
    notifyListeners();
  }

  void dismissCelebration() {
    _showConnectionCelebration = false;
    notifyListeners();
  }

  // --- Real-time updates handler ---
  void _handleSessionUpdate(PlaybackSession session) {
    final conn = _pairConnection;
    if (conn == null) return;

    _playbackSession = session;

    final song = session.currentSong;
    if (song == null) {
      _playbackService.stop();
      _loadedSongId = null;
      _isBuffering = false;
      _isPlaying = false;
    } else {
      if (_loadedSongId != song.id) {
        _loadCurrentSongSync(song);
      } else {
        if (session.isPlaying != _isPlaying) {
          if (session.isPlaying) {
            _playbackService.play();
            _isPlaying = true;
            if (song.isOwner(conn.deviceId)) {
              _startPositionSyncTimer();
            }
          } else {
            _playbackService.pause();
            _isPlaying = false;
            _stopPositionSyncTimer();
          }
        }

        if (session.lastUpdatedBy != conn.deviceId) {
          final diff = (session.positionSeconds - _elapsedSeconds).abs();
          if (diff > 2) {
            _elapsedSeconds = session.positionSeconds.toDouble();
            _playbackService.seek(Duration(seconds: session.positionSeconds));
          }
        }
      }
    }
    notifyListeners();
  }

  void _loadCurrentSongSync(SongItem song) async {
    final conn = _pairConnection;
    if (conn == null) return;

    _loadedSongId = song.id;
    _isBuffering = true;
    _isPlaying = false;
    _elapsedSeconds = 0;
    notifyListeners();

    await _playbackService.stop();

    if (song.isOwner(conn.deviceId)) {
      final localSong = _localLibrarySongs.firstWhere((s) => s.title == song.title && s.artist == song.artist, orElse: () => song);
      final finalSong = song.copyWith(localFilePath: localSong.localFilePath);

      final duration = await _playbackService.loadSong(finalSong);
      if (duration != null) {
        _isBuffering = false;
        _elapsedSeconds = 0;
        await _playbackService.seek(Duration.zero);
        if (_playbackSession?.isPlaying == true) {
          await _playbackService.play();
          _isPlaying = true;
          _startPositionSyncTimer();
        }
      }
    } else {
      final cachedPath = _getCachedFilePath(song.id);
      if (cachedPath != null) {
        final cachedSong = song.copyWith(cachedFilePath: cachedPath);
        final duration = await _playbackService.loadSong(cachedSong);
        if (duration != null) {
          _isBuffering = false;
          _playbackService.seek(Duration(seconds: _playbackSession?.positionSeconds ?? 0));
          if (_playbackSession?.isPlaying == true) {
            await _playbackService.play();
            _isPlaying = true;
          }
        }
      } else {
        if (_webrtcService != null && _webrtcService!.connectionState == WebRTCConnState.connected) {
          _webrtcService!.requestSongFile(song.id);
        }
      }
    }
    notifyListeners();
  }

  void _handleSongFileReceived(String songId, String cachedPath) async {
    final song = currentSong;
    if (song == null || song.id != songId) return;

    final cachedSong = song.copyWith(cachedFilePath: cachedPath);
    final duration = await _playbackService.loadSong(cachedSong);
    if (duration != null) {
      _isBuffering = false;
      _playbackService.seek(Duration(seconds: _playbackSession?.positionSeconds ?? 0));
      if (_playbackSession?.isPlaying == true) {
        await _playbackService.play();
        _isPlaying = true;
      }
      notifyListeners();
    }
  }

  Future<String?> _handleLocalFileRequested(String songId) async {
    for (final song in _localLibrarySongs) {
      final match = queue.firstWhere((q) => q.id == songId, orElse: () => const SongItem(id: '', title: '', artist: '', duration: Duration.zero, addedBy: ''));
      if (match.id.isNotEmpty && song.title == match.title && song.artist == match.artist) {
        return song.localFilePath;
      }
    }
    return null;
  }

  String? _getCachedFilePath(String songId) {
    try {
      final tempDir = Directory.systemTemp;
      final files = tempDir.listSync();
      for (final file in files) {
        if (file is File && file.path.contains(songId)) {
          return file.path;
        }
      }
    } catch (_) {}
    return null;
  }

  // --- Symmetric playback controls updates ---
  Future<void> togglePlayPause() async {
    final conn = _pairConnection;

    // ── Solo mode ──────────────────────────────────────────────
    if (conn == null) {
      final session = _localSession;
      if (session == null || currentSong == null) return;
      final nextPlaying = !_isPlaying;
      if (nextPlaying) {
        await _playbackService.play();
      } else {
        await _playbackService.pause();
      }
      _isPlaying = nextPlaying;
      _localSession = session.copyWith(
        isPlaying: nextPlaying,
        positionSeconds: _elapsedSeconds.round(),
        lastUpdatedAt: DateTime.now(),
      );
      notifyListeners();
      return;
    }

    // ── Paired mode ────────────────────────────────────────────
    final session = _playbackSession;
    if (session == null || currentSong == null) return;

    final nextPlaying = !session.isPlaying;
    final updated = session.copyWith(
      isPlaying: nextPlaying,
      positionSeconds: _elapsedSeconds.round(),
      lastUpdatedBy: conn.deviceId,
      lastUpdatedAt: DateTime.now(),
    );

    _isPlaying = nextPlaying;
    await _updateSessionAndBroadcast(updated);
  }

  Future<void> seekToFraction(double fraction) async {
    final conn = _pairConnection;
    final track = currentSong;
    if (track == null) return;

    final nextPos = (track.duration.inSeconds * fraction).clamp(0.0, track.duration.inSeconds.toDouble());
    _elapsedSeconds = nextPos;
    notifyListeners();
    await _playbackService.seek(Duration(seconds: nextPos.round()));

    // ── Solo mode ──────────────────────────────────────────────
    if (conn == null) {
      _localSession = _localSession?.copyWith(
        positionSeconds: nextPos.round(),
        lastUpdatedAt: DateTime.now(),
      );
      return;
    }

    // ── Paired mode ────────────────────────────────────────────
    final session = _playbackSession;
    if (session == null) return;
    final updated = session.copyWith(
      positionSeconds: nextPos.round(),
      lastUpdatedBy: conn.deviceId,
      lastUpdatedAt: DateTime.now(),
    );
    await _updateSessionAndBroadcast(updated);
  }

  Future<void> nextTrack({bool wrap = true}) async {
    final conn = _pairConnection;

    // ── Solo mode ──────────────────────────────────────────────
    if (conn == null) {
      final session = _localSession;
      if (session == null || queue.isEmpty) return;
      int nextIndex = session.currentIndex + 1;
      if (nextIndex >= queue.length) {
        if (!wrap) return;
        nextIndex = 0;
      }
      _localSession = session.copyWith(
        currentIndex: nextIndex,
        positionSeconds: 0,
        isPlaying: session.isPlaying,
        lastUpdatedAt: DateTime.now(),
      );
      notifyListeners();
      final next = _localSession!.currentSong;
      if (next != null) _loadLocalSong(next);
      return;
    }

    // ── Paired mode ────────────────────────────────────────────
    final session = _playbackSession;
    if (session == null || queue.isEmpty) return;

    int nextIndex = session.currentIndex + 1;
    if (nextIndex >= queue.length) {
      if (!wrap) return;
      nextIndex = 0;
    }

    final updated = session.copyWith(
      currentIndex: nextIndex,
      positionSeconds: 0,
      isPlaying: session.isPlaying,
      lastUpdatedBy: conn.deviceId,
      lastUpdatedAt: DateTime.now(),
    );

    await _updateSessionAndBroadcast(updated);
  }

  Future<void> previousTrack() async {
    final conn = _pairConnection;

    // ── Solo mode ──────────────────────────────────────────────
    if (conn == null) {
      final session = _localSession;
      if (session == null || queue.isEmpty) return;
      if (_elapsedSeconds > 3) {
        _elapsedSeconds = 0;
        notifyListeners();
        await _playbackService.seek(Duration.zero);
        _localSession = session.copyWith(positionSeconds: 0, lastUpdatedAt: DateTime.now());
        return;
      }
      int prevIndex = session.currentIndex - 1;
      if (prevIndex < 0) prevIndex = queue.length - 1;
      _localSession = session.copyWith(
        currentIndex: prevIndex,
        positionSeconds: 0,
        isPlaying: session.isPlaying,
        lastUpdatedAt: DateTime.now(),
      );
      notifyListeners();
      final prev = _localSession!.currentSong;
      if (prev != null) _loadLocalSong(prev);
      return;
    }

    // ── Paired mode ────────────────────────────────────────────
    final session = _playbackSession;
    if (session == null || queue.isEmpty) return;

    if (_elapsedSeconds > 3) {
      _elapsedSeconds = 0;
      notifyListeners();
      await _playbackService.seek(Duration.zero);
      final updated = session.copyWith(
        positionSeconds: 0,
        lastUpdatedBy: conn.deviceId,
        lastUpdatedAt: DateTime.now(),
      );
      await _updateSessionAndBroadcast(updated);
      return;
    }

    int prevIndex = session.currentIndex - 1;
    if (prevIndex < 0) {
      prevIndex = queue.length - 1;
    }

    final updated = session.copyWith(
      currentIndex: prevIndex,
      positionSeconds: 0,
      isPlaying: session.isPlaying,
      lastUpdatedBy: conn.deviceId,
      lastUpdatedAt: DateTime.now(),
    );

    await _updateSessionAndBroadcast(updated);
  }

  Future<void> _updateSessionAndBroadcast(PlaybackSession updated) async {
    final conn = _pairConnection;
    if (conn == null) return;

    // 1. Optimistic local update
    _playbackSession = updated;
    notifyListeners();

    // 2. Broadcast update to partner instantly via Websocket Broadcast
    if (_sessionSyncChannel != null) {
      await _supabaseService.broadcastSessionUpdate(_sessionSyncChannel!, conn.deviceId, updated);
    }

    // 3. Persist session state in Database
    await _supabaseService.updateSession(updated);
  }

  // --- Queue sync management ---
  Future<void> addSongToQueue(SongItem item) async {
    final conn = _pairConnection;

    // ── Solo mode ──────────────────────────────────────────────
    if (conn == null) {
      final current = _localSession ??
          PlaybackSession(
            pairId: 'local',
            queue: const [],
            currentIndex: 0,
            isPlaying: false,
            positionSeconds: 0,
            lastUpdatedBy: 'local-device',
            lastUpdatedAt: DateTime.now(),
          );

      final queuedSong = SongItem(
        id: 'song-${DateTime.now().microsecondsSinceEpoch}',
        title: item.title,
        artist: item.artist,
        duration: item.duration,
        addedBy: 'local-device',
        localFilePath: item.localFilePath,
      );

      final updated = current.copyWith(
        queue: [...current.queue, queuedSong],
        isPlaying: true, // auto-play on add
        lastUpdatedAt: DateTime.now(),
      );
      _localSession = updated;
      notifyListeners();

      // Auto-load the song if nothing is playing yet
      if (_loadedSongId == null) {
        _loadLocalSong(queuedSong);
      }
      return;
    }

    // ── Paired mode: bootstrap session if Supabase stream is lagging ──
    PlaybackSession session;
    if (_playbackSession == null) {
      final existing = await _supabaseService.getSession(conn.pairId).catchError((_) => null);
      if (existing != null) {
        session = existing;
        _playbackSession = existing;
      } else {
        session = PlaybackSession(
          pairId: conn.pairId,
          queue: const [],
          currentIndex: 0,
          isPlaying: false,
          positionSeconds: 0,
          lastUpdatedBy: conn.deviceId,
          lastUpdatedAt: DateTime.now(),
        );
        _playbackSession = session;
      }
    } else {
      session = _playbackSession!;
    }

    final queuedSong = SongItem(
      id: 'song-${DateTime.now().microsecondsSinceEpoch}',
      title: item.title,
      artist: item.artist,
      duration: item.duration,
      addedBy: conn.deviceId,
      localFilePath: item.localFilePath,
    );

    final updatedQueue = [...session.queue, queuedSong];
    final updated = session.copyWith(
      queue: updatedQueue,
      lastUpdatedBy: conn.deviceId,
      lastUpdatedAt: DateTime.now(),
    );

    await _updateSessionAndBroadcast(updated);
  }

  Future<void> removeSongFromQueue(int index) async {
    final conn = _pairConnection;

    // ── Solo mode ──────────────────────────────────────────────
    if (conn == null) {
      final session = _localSession;
      if (session == null || index < 0 || index >= queue.length) return;
      final wasCurrentSong = index == session.currentIndex;
      final updatedQueue = [...session.queue]..removeAt(index);
      int nextIndex = session.currentIndex;
      if (nextIndex >= updatedQueue.length) nextIndex = max(0, updatedQueue.length - 1);
      _localSession = session.copyWith(
        queue: updatedQueue,
        currentIndex: nextIndex,
        lastUpdatedAt: DateTime.now(),
      );
      notifyListeners();
      if (wasCurrentSong) {
        final next = _localSession!.currentSong;
        if (next != null) {
          _loadLocalSong(next);
        } else {
          await _playbackService.stop();
          _loadedSongId = null;
          _isPlaying = false;
          notifyListeners();
        }
      }
      return;
    }

    // ── Paired mode ────────────────────────────────────────────
    final session = _playbackSession;
    if (session == null || index < 0 || index >= queue.length) return;

    final updatedQueue = [...session.queue]..removeAt(index);
    int nextIndex = session.currentIndex;
    if (nextIndex >= updatedQueue.length) {
      nextIndex = max(0, updatedQueue.length - 1);
    }

    final updated = session.copyWith(
      queue: updatedQueue,
      currentIndex: nextIndex,
      lastUpdatedBy: conn.deviceId,
      lastUpdatedAt: DateTime.now(),
    );

    await _updateSessionAndBroadcast(updated);
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    final conn = _pairConnection;

    var actualNewIndex = newIndex;
    if (oldIndex < newIndex) actualNewIndex -= 1;

    // Shared logic: calculate the new list + adjusted currentIndex
    PlaybackSession? session = conn == null ? _localSession : _playbackSession;
    if (session == null) return;

    final list = [...session.queue];
    final item = list.removeAt(oldIndex);
    list.insert(actualNewIndex, item);

    int nextCurrentIndex = session.currentIndex;
    if (session.currentIndex == oldIndex) {
      nextCurrentIndex = actualNewIndex;
    } else if (session.currentIndex > oldIndex && session.currentIndex <= actualNewIndex) {
      nextCurrentIndex -= 1;
    } else if (session.currentIndex < oldIndex && session.currentIndex >= actualNewIndex) {
      nextCurrentIndex += 1;
    }

    // ── Solo mode ──────────────────────────────────────────────
    if (conn == null) {
      _localSession = session.copyWith(
        queue: list,
        currentIndex: nextCurrentIndex,
        lastUpdatedAt: DateTime.now(),
      );
      notifyListeners();
      return;
    }

    // ── Paired mode ────────────────────────────────────────────
    final updated = session.copyWith(
      queue: list,
      currentIndex: nextCurrentIndex,
      lastUpdatedBy: conn.deviceId,
      lastUpdatedAt: DateTime.now(),
    );
    await _updateSessionAndBroadcast(updated);
  }

  Future<void> clearQueue() async {
    final conn = _pairConnection;

    // ── Solo mode ──────────────────────────────────────────────
    if (conn == null) {
      _localSession = null;
      await _playbackService.stop();
      _loadedSongId = null;
      _isPlaying = false;
      notifyListeners();
      return;
    }

    // ── Paired mode ────────────────────────────────────────────
    final session = _playbackSession;
    if (session == null) return;

    final updated = session.copyWith(
      queue: const [],
      currentIndex: 0,
      isPlaying: false,
      positionSeconds: 0,
      lastUpdatedBy: conn.deviceId,
      lastUpdatedAt: DateTime.now(),
    );

    await _updateSessionAndBroadcast(updated);
  }

  // --- Local file management (Import) ---
  Future<int> importLocalSongs() async {
    if (_isImporting) return 0;

    _isImporting = true;
    notifyListeners();

    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: _audioExtensions,
      );

      if (result == null) return 0;

      final importedSongs = <SongItem>[];
      for (var index = 0; index < result.files.length; index++) {
        final file = result.files[index];
        final filePath = file.path;
        if (filePath == null || filePath.isEmpty) continue;

        if (_localLibrarySongs.any((song) => song.localFilePath == filePath)) {
          continue;
        }

        final details = _inferImportedSongDetails(file.name);
        final probedDuration =
            await _playbackService.probeFile(filePath) ??
            const Duration(minutes: 3);

        importedSongs.add(
          SongItem(
            id: 'local-${DateTime.now().microsecondsSinceEpoch}-$index',
            title: details.title,
            artist: details.artist,
            duration: probedDuration,
            addedBy: _pairConnection?.deviceId ?? 'me',
            localFilePath: filePath,
          ),
        );
      }

      if (importedSongs.isEmpty) return 0;

      _localLibrarySongs = [...importedSongs, ..._localLibrarySongs];
      await _persistLibrary();
      notifyListeners();
      return importedSongs.length;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  // --- Sync Timer for current playing song ---
  void _startPositionSyncTimer() {
    _positionSyncTimer?.cancel();
    _positionSyncTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final conn = _pairConnection;
      final session = _playbackSession;
      if (conn != null && session != null && _isPlaying && currentSong?.isOwner(conn.deviceId) == true) {
        final updated = session.copyWith(
          positionSeconds: _elapsedSeconds.round(),
          lastUpdatedBy: conn.deviceId,
          lastUpdatedAt: DateTime.now(),
        );
        _supabaseService.updateSession(updated);
      }
    });
  }

  void _stopPositionSyncTimer() {
    _positionSyncTimer?.cancel();
    _positionSyncTimer = null;
  }

  void _bindPlayback() {
    _positionSubscription = _playbackService.positionStream.listen((position) {
      _elapsedSeconds = position.inSeconds.toDouble();
      notifyListeners();
    });

    _playingSubscription = _playbackService.playingStream.listen((playing) {
      if (_isPlaying == playing) return;
      _isPlaying = playing;
      notifyListeners();
    });

    _completedSubscription = _playbackService.completedStream.listen((_) {
      _handleTrackCompleted();
    });
  }

  void _handleTrackCompleted() {
    // Solo mode: keep playing after auto-advance
    if (_pairConnection == null) {
      final session = _localSession;
      if (session == null || queue.isEmpty) return;
      int nextIndex = session.currentIndex + 1;
      if (nextIndex >= queue.length) nextIndex = 0;
      _localSession = session.copyWith(
        currentIndex: nextIndex,
        positionSeconds: 0,
        isPlaying: true,
        lastUpdatedAt: DateTime.now(),
      );
      notifyListeners();
      final next = _localSession!.currentSong;
      if (next != null) _loadLocalSong(next);
      return;
    }
    nextTrack(wrap: true);
  }

  // ---- Solo-mode song loader ------------------------------------------
  void _loadLocalSong(SongItem song) async {
    _loadedSongId = song.id;
    _isBuffering = true;
    _isPlaying = false;
    _elapsedSeconds = 0;
    notifyListeners();

    await _playbackService.stop();
    final localSong = _localLibrarySongs.firstWhere(
      (s) => s.title == song.title && s.artist == song.artist,
      orElse: () => song,
    );
    final songToLoad = song.copyWith(localFilePath: localSong.localFilePath ?? song.localFilePath);

    final duration = await _playbackService.loadSong(songToLoad);
    if (duration != null) {
      _isBuffering = false;
      await _playbackService.seek(Duration.zero);
      if (_localSession?.isPlaying == true) {
        await _playbackService.play();
        _isPlaying = true;
      }
      notifyListeners();
    }
  }

  // ---- Presence (heartbeat) ------------------------------------------
  void _startPresence(String pairId, String myDeviceId) {
    _stopPresence();
    _presenceChannel = _supabaseService.createPresenceChannel(
      pairId,
      myDeviceId,
      (partnerId) {
        _partnerDeviceId = partnerId;
        _lastPartnerHeartbeat = DateTime.now();
        if (!_partnerOnline) {
          _partnerOnline = true;
          notifyListeners();
        }
      },
    );

    if (_presenceChannel == null) return;

    // Immediate ping + every 8 seconds
    _supabaseService.sendPresencePing(_presenceChannel!, myDeviceId);
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _supabaseService.sendPresencePing(_presenceChannel!, myDeviceId);
    });

    // Watchdog: mark partner offline if no beat for 20 seconds
    _partnerWatchdogTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final beat = _lastPartnerHeartbeat;
      if (beat != null && DateTime.now().difference(beat).inSeconds > 20) {
        if (_partnerOnline) {
          _partnerOnline = false;
          _partnerDeviceId = null;
          notifyListeners();
        }
      }
    });
  }

  void _stopPresence() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _partnerWatchdogTimer?.cancel();
    _partnerWatchdogTimer = null;
    if (_presenceChannel != null) {
      _supabaseService.removeChannel(_presenceChannel!);
      _presenceChannel = null;
    }
    if (_sessionSyncChannel != null) {
      _supabaseService.removeChannel(_sessionSyncChannel!);
      _sessionSyncChannel = null;
    }
    _partnerOnline = false;
    _partnerDeviceId = null;
    _lastPartnerHeartbeat = null;
  }

  Future<void> _persistLibrary() {
    return _store.saveLibrary(songs: _localLibrarySongs, playlists: _playlists);
  }

  _ImportedSongDetails _inferImportedSongDetails(String fileName) {
    final stem = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '').trim();
    if (stem.contains(' - ')) {
      final parts = stem.split(' - ');
      if (parts.length >= 2) {
        return _ImportedSongDetails(
          title: parts.sublist(1).join(' - ').trim(),
          artist: parts.first.trim(),
        );
      }
    }

    return _ImportedSongDetails(
      title: stem.isEmpty ? 'Untitled track' : stem,
      artist: 'Local Vibe',
    );
  }

  // --- Local Playlist Toggle ---
  Future<void> createPlaylist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    _playlists = [
      PlaylistItem(
        id: 'playlist-${DateTime.now().microsecondsSinceEpoch}',
        name: trimmed,
        songIds: const [],
        updatedAt: DateTime.now(),
      ),
      ..._playlists,
    ];
    await _persistLibrary();
    notifyListeners();
  }

  Future<void> toggleSongInPlaylist(String playlistId, String songId) async {
    _playlists = _playlists.map((playlist) {
      if (playlist.id != playlistId) return playlist;
      final updatedSongIds = [...playlist.songIds];
      if (updatedSongIds.contains(songId)) {
        updatedSongIds.remove(songId);
      } else {
        updatedSongIds.add(songId);
      }
      return playlist.copyWith(
        songIds: updatedSongIds,
        updatedAt: DateTime.now(),
      );
    }).toList(growable: false);

    await _persistLibrary();
    notifyListeners();
  }

  List<SongItem> songsForPlaylist(PlaylistItem playlist) {
    return playlist.songIds
        .map((id) => _localLibrarySongs.firstWhere((s) => s.id == id, orElse: () => const SongItem(id: '', title: '', artist: '', duration: Duration.zero, addedBy: '')))
        .where((s) => s.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  void dispose() {
    _stopPositionSyncTimer();
    _stopPresence();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playingSubscription?.cancel();
    _completedSubscription?.cancel();
    _sessionSubscription?.cancel();
    _webrtcService?.dispose();
    _playbackService.dispose();
    super.dispose();
  }
}

class _ImportedSongDetails {
  const _ImportedSongDetails({required this.title, required this.artist});
  final String title;
  final String artist;
}
