import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../models/song_item.dart';

abstract class PlaybackService {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get playingStream;
  Stream<void> get completedStream;

  Future<Duration?> loadSong(SongItem song);
  Future<Duration?> probeFile(String filePath);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioPlaybackService implements PlaybackService {
  JustAudioPlaybackService({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<bool> get playingStream =>
      _player.playerStateStream.map((state) => state.playing).distinct();

  @override
  Stream<void> get completedStream => _player.playerStateStream
      .where((state) => state.processingState == ProcessingState.completed)
      .map((_) {});

  @override
  Future<Duration?> loadSong(SongItem song) async {
    final filePath = song.activePath;
    if (filePath == null || filePath.isEmpty) {
      await _player.stop();
      return song.duration;
    }

    try {
      return await _player.setFilePath(filePath);
    } catch (_) {
      await _player.stop();
      return null;
    }
  }

  @override
  Future<Duration?> probeFile(String filePath) async {
    final probePlayer = AudioPlayer();
    try {
      return await probePlayer.setFilePath(filePath);
    } catch (_) {
      return null;
    } finally {
      await probePlayer.dispose();
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
