import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:music_listen/src/app.dart';
import 'package:music_listen/src/models/pair_connection.dart';
import 'package:music_listen/src/models/song_item.dart';
import 'package:music_listen/src/models/playback_session.dart';
import 'package:music_listen/src/services/local_store.dart';
import 'package:music_listen/src/services/playback_service.dart';
import 'package:music_listen/src/services/supabase_service.dart';
import 'package:music_listen/src/services/webrtc_service.dart';
import 'package:music_listen/src/state/app_controller.dart';

void main() {
  testWidgets('shows setup screen on fresh install and allows saving credentials', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final controller = AppController(
      LocalStore(),
      playbackService: TestPlaybackService(),
      supabaseService: TestSupabaseService(),
    );

    await tester.pumpWidget(MusicListenApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Configure Backend'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Supabase Project URL'),
      'https://test.supabase.co',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Anon / Public Key'),
      'test-anon-key-for-project-validation',
    );
    await tester.tap(find.text('Save & Connect'));
    await tester.pumpAndSettle();

    expect(find.text('Connect with your person'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('shows pairing flow when credentials exist', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'owner_supabase_url': 'https://mock.supabase.co',
      'owner_supabase_anon_key': 'mock-anon-key-that-is-long-enough-for-validation',
    });

    final controller = AppController(
      LocalStore(),
      playbackService: TestPlaybackService(),
      supabaseService: TestSupabaseService(),
      webrtcServiceBuilder: (p, d, s) => TestWebRTCService(p, d, s),
    );

    await tester.pumpWidget(MusicListenApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Connect with your person'), findsOneWidget);
    expect(find.text('Join a space'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('allows pairing to be undone from the confirmation screen', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'owner_supabase_url': 'https://mock.supabase.co',
      'owner_supabase_anon_key': 'mock-anon-key-that-is-long-enough-for-validation',
    });

    final controller = AppController(
      LocalStore(),
      playbackService: TestPlaybackService(),
      supabaseService: TestSupabaseService(),
      webrtcServiceBuilder: (p, d, s) => TestWebRTCService(p, d, s),
    );

    await tester.pumpWidget(MusicListenApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'cozy-1234');
    await tester.ensureVisible(find.text("Enter Music Space"));
    await tester.tap(find.text("Enter Music Space"));
    await tester.pumpAndSettle();

    expect(find.text('Go back and pair again'), findsOneWidget);

    await tester.ensureVisible(find.text('Go back and pair again'));
    await tester.tap(find.text('Go back and pair again'));
    await tester.pumpAndSettle();

    expect(find.text('Connect with your person'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('keeps playback controls within a narrow phone width', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'owner_supabase_url': 'https://mock.supabase.co',
      'owner_supabase_anon_key': 'mock-anon-key-that-is-long-enough-for-validation',
      'pair_connection': jsonEncode(
        PairConnection(
          pairId: 'COZY-1234',
          deviceId: 'device-test',
          createdAt: DateTime(2026, 4, 20),
        ).toJson(),
      ),
      'songs': jsonEncode([
        const SongItem(
          id: 'local-track-1',
          title: 'Soft Signal',
          artist: 'Velvet Harbor',
          duration: Duration(minutes: 3, seconds: 42),
          addedBy: 'device-test',
          localFilePath: 'C:/music/soft_signal.mp3',
        ).toJson(),
      ]),
      'playlists': jsonEncode([]),
    });

    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = AppController(
      LocalStore(),
      playbackService: TestPlaybackService(),
      supabaseService: TestSupabaseService(),
      webrtcServiceBuilder: (p, d, s) => TestWebRTCService(p, d, s),
    );

    await tester.pumpWidget(MusicListenApp(controller: controller));
    await tester.pumpAndSettle();

    // Verify app starts without crash
    expect(tester.takeException(), isNull);

    controller.dispose();
  });
}

class TestPlaybackService implements PlaybackService {
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();
  final StreamController<bool> _playingController =
      StreamController<bool>.broadcast();
  final StreamController<void> _completedController =
      StreamController<void>.broadcast();

  @override
  Stream<void> get completedStream => _completedController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Future<void> dispose() async {
    await _positionController.close();
    await _durationController.close();
    await _playingController.close();
    await _completedController.close();
  }

  @override
  Future<Duration?> loadSong(SongItem song) async => song.duration;

  @override
  Future<void> pause() async {
    _playingController.add(false);
  }

  @override
  Future<void> play() async {
    _playingController.add(true);
  }

  @override
  Future<Duration?> probeFile(String filePath) async =>
      const Duration(minutes: 3);

  @override
  Future<void> seek(Duration position) async {
    _positionController.add(position);
  }

  @override
  Future<void> stop() async {
    _playingController.add(false);
  }
}

class TestSupabaseService extends SupabaseService {
  @override
  bool get isInitialized => true;

  @override
  void initCredentials(String url, String key) {
    // Do nothing to avoid starting real client and timers
  }

  @override
  Future<PlaybackSession?> getSession(String pairId) async => null;

  @override
  Future<void> updateSession(PlaybackSession session) async {}

  @override
  Stream<PlaybackSession> streamSession(String pairId) => const Stream.empty();
}

class TestWebRTCService extends WebRTCService {
  TestWebRTCService(
    String pairId,
    String myDeviceId,
    SupabaseService supabaseService,
  ) : super(
          pairId: pairId,
          myDeviceId: myDeviceId,
          supabaseService: supabaseService,
        );

  @override
  void initSignaling() {
    // Override to do nothing in test environment
  }
}
