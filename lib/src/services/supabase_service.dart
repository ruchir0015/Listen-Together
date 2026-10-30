import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/src/types.dart';
import '../models/playback_session.dart';

class SupabaseService {
  SupabaseClient? _client;

  SupabaseClient get client {
    if (_client == null) {
      throw StateError('Supabase client has not been initialized. Please configure credentials.');
    }
    return _client!;
  }

  bool get isInitialized => _client != null;

  void initCredentials(String url, String key) {
    try {
      _client = SupabaseClient(url, key);
    } catch (e) {
      print('Failed to initialize Supabase client: $e');
      _client = null;
    }
  }

  Future<PlaybackSession?> getSession(String pairId) async {
    if (!isInitialized) return null;
    try {
      final res = await client
          .from('playback_sessions')
          .select()
          .eq('pair_id', pairId)
          .maybeSingle();
      if (res == null) return null;
      return PlaybackSession.fromJson(res);
    } catch (e) {
      print('Error getting session: $e');
      return null;
    }
  }

  Future<void> updateSession(PlaybackSession session) async {
    if (!isInitialized) return;
    try {
      await client.from('playback_sessions').upsert(session.toJson());
    } catch (e) {
      print('Error updating session: $e');
    }
  }

  Stream<PlaybackSession> streamSession(String pairId) {
    final controller = StreamController<PlaybackSession>();

    if (!isInitialized) {
      controller.close();
      return controller.stream;
    }

    // Initial fetch
    getSession(pairId).then((session) {
      if (session != null && !controller.isClosed) {
        controller.add(session);
      }
    });

    final subscription = client
        .channel('public:playback_sessions:pair_id=eq.$pairId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'playback_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'pair_id',
            value: pairId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              try {
                final session = PlaybackSession.fromJson(payload.newRecord);
                if (!controller.isClosed) {
                  controller.add(session);
                }
              } catch (e) {
                print('Error parsing session stream: $e');
              }
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      try {
        client.removeChannel(subscription);
      } catch (_) {}
      controller.close();
    };

    return controller.stream;
  }

  RealtimeChannel createSignalingChannel(
    String pairId,
    String myDeviceId,
    void Function(Map<String, dynamic> payload) onMessageReceived,
  ) {
    if (!isInitialized) {
      throw StateError('Supabase client not initialized.');
    }
    final channelName = 'webrtc_signaling_$pairId';
    try {
      final existing = client.channel(channelName);
      client.removeChannel(existing);
    } catch (_) {}
    final channel = client.channel(channelName);

    channel.onBroadcast(
      event: 'signaling',
      callback: (payload) {
        final sender = payload['sender'] as String?;
        if (sender != myDeviceId) {
          onMessageReceived(payload);
        }
      },
    );

    return channel;
  }

  Future<void> sendSignalingMessage(
    RealtimeChannel channel,
    String myDeviceId,
    Map<String, dynamic> message,
  ) async {
    if (!isInitialized) return;
    final payload = {
      'sender': myDeviceId,
      ...message,
    };
    try {
      await channel.send(
        type: RealtimeListenTypes.broadcast,
        event: 'signaling',
        payload: payload,
      );
    } catch (e) {
      print('Error sending signaling message: $e');
    }
  }

  void removeChannel(RealtimeChannel channel) {
    if (!isInitialized) return;
    try {
      client.removeChannel(channel);
    } catch (_) {}
  }

  /// Opens a Realtime broadcast channel that fires [onPartnerHeartbeat] every
  /// time the partner sends a ping. Returns null if Supabase is not ready.
  RealtimeChannel? createPresenceChannel(
    String pairId,
    String myDeviceId,
    void Function(String partnerDeviceId) onPartnerHeartbeat,
  ) {
    if (!isInitialized) return null;
    try {
      final channel = client.channel('presence_$pairId');
      channel
          .onBroadcast(
            event: 'heartbeat',
            callback: (payload) {
              final sender = payload['device_id'] as String?;
              if (sender != null && sender != myDeviceId) {
                onPartnerHeartbeat(sender);
              }
            },
          )
          .subscribe();
      return channel;
    } catch (e) {
      print('Failed to create presence channel: $e');
      return null;
    }
  }

  /// Sends a lightweight heartbeat broadcast so the partner knows we are alive.
  Future<void> sendPresencePing(RealtimeChannel channel, String myDeviceId) async {
    try {
      await channel.send(
        type: RealtimeListenTypes.broadcast,
        event: 'heartbeat',
        payload: {'device_id': myDeviceId},
      );
    } catch (_) {}
  }

  RealtimeChannel? createSessionSyncChannel(
    String pairId,
    String myDeviceId,
    void Function(PlaybackSession session) onSessionReceived,
  ) {
    if (!isInitialized) return null;
    try {
      final channel = client.channel('session_sync_$pairId');
      channel
          .onBroadcast(
            event: 'session_update',
            callback: (payload) {
              final sender = payload['sender'] as String?;
              if (sender != myDeviceId) {
                final sessionMap = payload['session'] as Map<String, dynamic>?;
                if (sessionMap != null) {
                  try {
                    final session = PlaybackSession.fromJson(sessionMap);
                    onSessionReceived(session);
                  } catch (_) {}
                }
              }
            },
          )
          .subscribe();
      return channel;
    } catch (e) {
      print('Failed to create session sync channel: $e');
      return null;
    }
  }

  Future<void> broadcastSessionUpdate(
    RealtimeChannel channel,
    String myDeviceId,
    PlaybackSession session,
  ) async {
    try {
      await channel.send(
        type: RealtimeListenTypes.broadcast,
        event: 'session_update',
        payload: {
          'sender': myDeviceId,
          'session': session.toJson(),
        },
      );
    } catch (_) {}
  }
}

