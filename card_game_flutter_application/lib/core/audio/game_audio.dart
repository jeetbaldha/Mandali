import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameAudio extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = GameAudio._();
  GameAudio._();
  bool sound = true, music = false, haptics = true, reduceMotion = false;
  double volume = .55;
  bool ready = false, _foreground = true, _voice = false;
  final List<AudioPlayer> _effects = [];
  AudioPlayer? _music;
  SharedPreferences? _prefs;
  int _channel = 0, _lastPlay = 0;
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      sound = _prefs!.getBool('sound') ?? true;
      music = _prefs!.getBool('music') ?? false;
      haptics = _prefs!.getBool('haptics') ?? true;
      reduceMotion = _prefs!.getBool('reduceMotion') ?? false;
      volume = _prefs!.getDouble('volume') ?? .55;
      final ctx = AudioContext(
        android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      );
      for (var i = 0; i < 3; i++) {
        final p = AudioPlayer();
        await p.setAudioContext(ctx);
        _effects.add(p);
      }
      _music = AudioPlayer();
      await _music!.setAudioContext(ctx);
      await _music!.setReleaseMode(ReleaseMode.loop);
      WidgetsBinding.instance.addObserver(this);
      ready = true;
      notifyListeners();
      await _updateMusic();
      await play('startup');
    } catch (_) {
      ready = false;
    }
  }

  Future<void> play(String cue) async {
    if (!ready || !sound || !_foreground || _voice || volume == 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPlay < 70) return;
    _lastPlay = now;
    try {
      final p = _effects[_channel++ % _effects.length];
      await p.stop();
      await p.play(AssetSource('audio/$cue.wav'), volume: volume);
    } catch (_) {
      /* Audio never blocks a legal game action. */
    }
  }

  void tap() {
    unawaited(play('button'));
    if (ready && haptics) unawaited(HapticFeedback.selectionClick());
  }

  void voiceActive(bool value) {
    if (_voice == value) return;
    _voice = value;
    if (value) {
      for (final p in _effects) {
        unawaited(p.stop());
      }
    }
    unawaited(_updateMusic());
  }

  Future<void> update({
    bool? sound,
    bool? music,
    bool? haptics,
    bool? reduceMotion,
    double? volume,
  }) async {
    this.sound = sound ?? this.sound;
    this.music = music ?? this.music;
    this.haptics = haptics ?? this.haptics;
    this.reduceMotion = reduceMotion ?? this.reduceMotion;
    this.volume = volume ?? this.volume;
    notifyListeners();
    await _prefs?.setBool('sound', this.sound);
    await _prefs?.setBool('music', this.music);
    await _prefs?.setBool('haptics', this.haptics);
    await _prefs?.setBool('reduceMotion', this.reduceMotion);
    await _prefs?.setDouble('volume', this.volume);
    if (!this.sound) {
      for (final p in _effects) {
        await p.stop();
      }
    }
    await _updateMusic();
  }

  Future<void> _updateMusic() async {
    if (!ready) return;
    try {
      if (!music || !_foreground || _voice) {
        await _music?.pause();
        return;
      }
      await _music?.setVolume(volume * .4);
      if (_music?.state != PlayerState.playing) {
        await _music?.play(AssetSource('audio/music.wav'), volume: volume * .4);
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      for (final p in _effects) {
        unawaited(p.stop());
      }
    }
    unawaited(_updateMusic());
  }
}

class AudioSettings extends StatelessWidget {
  const AudioSettings({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: GameAudio.instance,
    builder: (context, _) {
      final a = GameAudio.instance;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Sound effects'),
            value: a.sound,
            onChanged: (v) => a.update(sound: v),
          ),
          SwitchListTile(
            title: const Text('Music'),
            value: a.music,
            onChanged: (v) => a.update(music: v),
          ),
          ListTile(
            title: const Text('Volume'),
            subtitle: Slider(
              value: a.volume,
              label: '${(a.volume * 100).round()}%',
              divisions: 20,
              onChanged: (v) => a.update(volume: v),
            ),
          ),
          SwitchListTile(
            title: const Text('Haptic feedback'),
            value: a.haptics,
            onChanged: (v) => a.update(haptics: v),
          ),
          SwitchListTile(
            title: const Text('Reduce motion'),
            value: a.reduceMotion,
            onChanged: (v) => a.update(reduceMotion: v),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Game audio pauses during live voice chat and while the app is in the background.',
            ),
          ),
        ],
      );
    },
  );
}
