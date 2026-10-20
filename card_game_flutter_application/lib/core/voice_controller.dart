import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'game_client.dart';

class VoiceController extends ChangeNotifier with WidgetsBindingObserver {
  final GameClient client;
  lk.Room? room;
  bool mic = false;
  bool speaker = true;
  bool pushToTalk = false;
  bool joining = false;
  String? error;
  String? joinedRoomId;
  final Set<String> mutedPlayers = {};
  lk.EventsListener<lk.RoomEvent>? listener;
  Future<void> _microphoneQueue = Future.value();
  VoiceController(this.client) {
    WidgetsBinding.instance.addObserver(this);
  }
  bool get connected => room?.connectionState == lk.ConnectionState.connected;
  bool speaking(String id) =>
      room?.activeSpeakers.any((p) => p.identity == id) ?? false;
  String get status => room?.connectionState.name ?? 'disconnected';
  Future<void> join() async {
    if (joining || client.roomId == null) return;
    joining = true;
    error = null;
    notifyListeners();
    try {
      await leave();
      final credentials = await client.request(
        '/voice/token',
        body: {'roomId': client.roomId},
      );
      final next = lk.Room();
      room = next;
      next.addListener(notifyListeners);
      listener = next.createListener()
        ..on<lk.TrackSubscribedEvent>((event) {
          unawaited(_applyOutput());
        });
      await next.connect(credentials['url'], credentials['token']);
      joinedRoomId = client.roomId;
      await lk.AudioManager.instance.setSpeakerOutputPreferred(true);
      mic = false;
      _publishStatus();
    } catch (e) {
      error = '$e';
    } finally {
      joining = false;
      notifyListeners();
    }
  }

  Future<void> setMic(bool enabled) {
    _microphoneQueue = _microphoneQueue.then((_) => _setMic(enabled));
    return _microphoneQueue;
  }

  Future<void> _setMic(bool enabled) async {
    try {
      await room?.localParticipant?.setMicrophoneEnabled(enabled);
      mic = enabled && connected;
      error = null;
    } catch (e) {
      error = 'Microphone unavailable: $e';
      mic = false;
    }
    _publishStatus();
    notifyListeners();
  }

  Future<void> setSpeaker(bool enabled) async {
    speaker = enabled;
    await _applyOutput();
    _publishStatus();
    notifyListeners();
  }

  Future<void> mutePlayer(String id) async {
    if (!mutedPlayers.remove(id)) mutedPlayers.add(id);
    await _applyOutput();
    notifyListeners();
  }

  Future<void> _applyOutput() async {
    for (final p
        in room?.remoteParticipants.values ?? <lk.RemoteParticipant>[]) {
      for (final publication in p.audioTrackPublications) {
        final track = publication.track;
        if (track is lk.RemoteAudioTrack) {
          if (speaker && !mutedPlayers.contains(p.identity)) {
            await track.enable();
          } else {
            await track.disable();
          }
        }
      }
    }
  }

  void _publishStatus() {
    client.socket?.emit('voice:status', {
      'roomId': client.roomId,
      'mic': mic,
      'speaker': speaker,
    });
  }

  Future<void> leave() async {
    await _microphoneQueue;
    await listener?.dispose();
    listener = null;
    final old = room;
    room = null;
    old?.removeListener(notifyListeners);
    await old?.disconnect();
    await old?.dispose();
    mic = false;
    joinedRoomId = null;
    _publishStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mic) unawaited(setMic(false));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(leave());
    super.dispose();
  }
}
