import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import 'supabase_service.dart';

enum WebRTCConnState { disconnected, connecting, connected, failed }

class WebRTCService extends ChangeNotifier {
  WebRTCService({
    required this.pairId,
    required this.myDeviceId,
    required this.supabaseService,
  }) {
    initSignaling();
  }

  final String pairId;
  final String myDeviceId;
  final SupabaseService supabaseService;

  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  RealtimeChannel? _signalingChannel;
  String? _partnerDeviceId;

  WebRTCConnState _connectionState = WebRTCConnState.disconnected;
  WebRTCConnState get connectionState => _connectionState;

  bool _isTransferring = false;
  bool get isTransferring => _isTransferring;
  String? _transferringSongId;
  String? get transferringSongId => _transferringSongId;
  double _transferProgress = 0.0;
  double get transferProgress => _transferProgress;
  String _transferStatus = '';
  String get transferStatus => _transferStatus;

  void Function(String songId, String cachedPath)? onSongFileReceived;
  Future<String?> Function(String songId)? onLocalFileRequested;

  File? _receivedFile;
  int _receivedBytes = 0;
  int _expectedBytes = 0;
  String? _receivingSongId;
  String? _receivingExtension;

  void initSignaling() {
    _signalingChannel = supabaseService.createSignalingChannel(
      pairId,
      myDeviceId,
      _handleSignalingMessage,
    );

    _signalingChannel!.onPresenceSync((_) {
      final states = _signalingChannel!.presenceState();
      final partnerIds = states
          .expand((state) => state.presences)
          .map((presence) => presence.payload['deviceId'] as String?)
          .whereType<String>()
          .where((id) => id != myDeviceId)
          .toList();

      if (partnerIds.isNotEmpty) {
        final partnerId = partnerIds.first;
        if (_partnerDeviceId != partnerId) {
          _partnerDeviceId = partnerId;
          _checkAndInitiateCall();
        }
      }
    });

    _signalingChannel!.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _signalingChannel!.track({
          'deviceId': myDeviceId,
        });
      }
    });
  }

  void _checkAndInitiateCall() {
    if (_partnerDeviceId == null) return;
    final isCaller = myDeviceId.compareTo(_partnerDeviceId!) < 0;
    if (isCaller) {
      _initiateCall();
    }
  }

  Future<void> _initiateCall() async {
    if (_connectionState == WebRTCConnState.connected ||
        _connectionState == WebRTCConnState.connecting) {
      return;
    }

    _updateState(WebRTCConnState.connecting);
    await _createPeerConnection();

    final dcInit = RTCDataChannelInit()..binaryType = 'binary';
    _dataChannel = await _peerConnection!.createDataChannel('audio-stream', dcInit);
    _setupDataChannel();

    final offer = await _peerConnection!.createOffer({
      'mandatory': {'OfferToReceiveAudio': false, 'OfferToReceiveVideo': false},
      'optional': [],
    });
    await _peerConnection!.setLocalDescription(offer);

    await supabaseService.sendSignalingMessage(_signalingChannel!, myDeviceId, {
      'type': 'offer',
      'sdp': offer.sdp,
    });
  }

  Future<void> _handleSignalingMessage(Map<String, dynamic> payload) async {
    final type = payload['type'] as String?;
    if (type == null) return;

    if (type == 'offer') {
      _updateState(WebRTCConnState.connecting);
      await _createPeerConnection();

      final sdp = payload['sdp'] as String;
      await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));

      final answer = await _peerConnection!.createAnswer({
        'mandatory': {'OfferToReceiveAudio': false, 'OfferToReceiveVideo': false},
        'optional': [],
      });
      await _peerConnection!.setLocalDescription(answer);

      await supabaseService.sendSignalingMessage(_signalingChannel!, myDeviceId, {
        'type': 'answer',
        'sdp': answer.sdp,
      });
    } else if (type == 'answer') {
      final sdp = payload['sdp'] as String;
      await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    } else if (type == 'candidate') {
      final candidateMap = payload['candidate'] as Map<String, dynamic>;
      final candidate = RTCIceCandidate(
        candidateMap['candidate'] as String,
        candidateMap['sdpMid'] as String,
        candidateMap['sdpMLineIndex'] as int,
      );
      await _peerConnection?.addCandidate(candidate);
    }
  }

  Future<void> _createPeerConnection() async {
    if (_peerConnection != null) {
      await _peerConnection!.close();
    }

    _peerConnection = await createPeerConnection(
      AppConfig.rtcConfig,
      {
        'mandatory': {},
        'optional': [{'DtlsSrtpKeyAgreement': true}],
      },
    );

    _peerConnection!.onIceCandidate = (candidate) {
      supabaseService.sendSignalingMessage(_signalingChannel!, myDeviceId, {
        'type': 'candidate',
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    _peerConnection!.onIceConnectionState = (state) {
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
          _updateState(WebRTCConnState.connected);
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          _updateState(WebRTCConnState.disconnected);
          _checkAndInitiateCall();
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _updateState(WebRTCConnState.failed);
          _checkAndInitiateCall();
          break;
        default:
          break;
      }
    };

    _peerConnection!.onDataChannel = (channel) {
      _dataChannel = channel;
      _setupDataChannel();
    };
  }

  void _setupDataChannel() {
    if (_dataChannel == null) return;

    _dataChannel!.onDataChannelState = (state) {
      notifyListeners();
    };

    _dataChannel!.onMessage = (RTCDataChannelMessage msg) {
      if (msg.isBinary) {
        _handleBinaryChunk(msg.binary);
      } else {
        _handleTextMessage(msg.text);
      }
    };
  }

  void _handleTextMessage(String text) {
    try {
      final data = jsonDecode(text) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'request') {
        final songId = data['songId'] as String;
        _startStreamingFileToPeer(songId);
      } else if (type == 'start') {
        _receivingSongId = data['songId'] as String;
        _expectedBytes = data['size'] as int;
        _receivingExtension = data['extension'] as String? ?? 'mp3';
        _receivedBytes = 0;
        _isTransferring = true;
        _transferringSongId = _receivingSongId;
        _transferProgress = 0.0;
        _transferStatus = 'Buffering...';
        notifyListeners();

        final tempDir = Directory.systemTemp;
        _receivedFile = File('${tempDir.path}/$_receivingSongId.$_receivingExtension');
        if (_receivedFile!.existsSync()) {
          _receivedFile!.deleteSync();
        }
        _receivedFile!.createSync();
      } else if (type == 'end') {
        if (_receivedFile != null && _receivingSongId != null) {
          final songId = _receivingSongId!;
          final path = _receivedFile!.path;
          _isTransferring = false;
          _transferringSongId = null;
          _transferProgress = 1.0;
          _transferStatus = 'Sync Complete';
          notifyListeners();
          onSongFileReceived?.call(songId, path);
        }
        _receivedFile = null;
        _receivingSongId = null;
      }
    } catch (e) {
      print('Error parsing RTC Text Message: $e');
    }
  }

  void _handleBinaryChunk(Uint8List chunk) {
    if (_receivedFile == null) return;
    try {
      _receivedFile!.writeAsBytesSync(chunk, mode: FileMode.append);
      _receivedBytes += chunk.length;
      if (_expectedBytes > 0) {
        _transferProgress = (_receivedBytes / _expectedBytes).clamp(0.0, 1.0);
      }
      notifyListeners();
    } catch (e) {
      print('Error writing binary chunk: $e');
    }
  }

  Future<void> requestSongFile(String songId) async {
    if (_dataChannel == null || _connectionState != WebRTCConnState.connected) {
      return;
    }
    final request = jsonEncode({
      'type': 'request',
      'songId': songId,
    });
    await _dataChannel!.send(RTCDataChannelMessage(request));
  }

  Future<void> _startStreamingFileToPeer(String songId) async {
    if (onLocalFileRequested == null) return;
    final filePath = await onLocalFileRequested!(songId);
    if (filePath == null || filePath.isEmpty) return;

    final file = File(filePath);
    if (!file.existsSync()) return;

    final size = file.lengthSync();
    final extension = filePath.split('.').last;

    _isTransferring = true;
    _transferringSongId = songId;
    _transferProgress = 0.0;
    _transferStatus = 'Streaming...';
    notifyListeners();

    final startMsg = jsonEncode({
      'type': 'start',
      'songId': songId,
      'size': size,
      'extension': extension,
    });
    await _dataChannel!.send(RTCDataChannelMessage(startMsg));

    final fileStream = file.openRead();
    int sentBytes = 0;

    await for (final chunk in fileStream) {
      if (_connectionState != WebRTCConnState.connected || _dataChannel == null) {
        break;
      }

      final bytes = Uint8List.fromList(chunk);
      await _dataChannel!.send(RTCDataChannelMessage.fromBinary(bytes));
      sentBytes += bytes.length;
      _transferProgress = (sentBytes / size).clamp(0.0, 1.0);
      notifyListeners();

      await Future<void>.delayed(const Duration(milliseconds: 12));
    }

    if (_connectionState == WebRTCConnState.connected && _dataChannel != null) {
      final endMsg = jsonEncode({
        'type': 'end',
        'songId': songId,
      });
      await _dataChannel!.send(RTCDataChannelMessage(endMsg));
    }

    _isTransferring = false;
    _transferringSongId = null;
    _transferProgress = 1.0;
    _transferStatus = 'Stream Complete';
    notifyListeners();
  }

  void _updateState(WebRTCConnState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _dataChannel?.close();
    _peerConnection?.close();
    if (_signalingChannel != null) {
      supabaseService.removeChannel(_signalingChannel!);
    }
    super.dispose();
  }
}
