import 'dart:async';

import '../../game/controllers/game_controller.dart';
import 'game_audio.dart';

/// Snapshot transitions select cues; ticking clocks do not retrigger table sounds.
class TableAudio {
  final GameController controller;
  Json? _previous;
  bool _connected;
  TableAudio(this.controller) : _connected = controller.connected {
    _previous = controller.room;
    controller.addListener(_changed);
  }
  void _changed() {
    final room = controller.room, old = _previous;
    String? cue;
    if (controller.connected && !_connected) cue = 'reconnect';
    _connected = controller.connected;
    if (room != null) {
      final g = room['game'] as Json?, before = old?['game'] as Json?;
      if (old == null || old['id'] != room['id']) {
        cue = 'room_joined';
      } else if ((room['players'] as List).length >
          (old['players'] as List).length) {
        cue = 'player_joined';
      } else if ((room['players'] as List).length <
          (old['players'] as List).length) {
        cue = 'player_left';
      }
      if (g != null) {
        if (g['id'] != before?['id']) {
          cue = 'shuffle';
        } else if (g['phase'] == 'RESULT' && before?['phase'] != 'RESULT') {
          cue = g['result']['kind'] == 'DRAW' ? 'draw' : 'winner';
        } else if (g['phase'] == 'REVEAL' && before?['phase'] != 'REVEAL') {
          cue = 'show';
        } else if (g['cardCount'] != before?['cardCount']) {
          cue = 'deal';
        } else {
          final mine = controller.handPlayer;
          final prior = (before?['players'] as List? ?? [])
              .cast<Json>()
              .where((p) => p['id'] == controller.selfId)
              .firstOrNull;
          if (mine?['seen'] == true && prior?['seen'] != true) {
            cue = 'flip';
          } else if ((g['players'] as List)
                  .where((p) => p['folded'] == true)
                  .length >
              (before?['players'] as List? ?? [])
                  .where((p) => p['folded'] == true)
                  .length) {
            cue = 'fold';
          } else if ((g['pot'] as num) > ((before?['pot'] as num?) ?? 0)) {
            cue = mine?['blind'] == true ? 'blind' : 'call';
          } else if ((g['pending'] as List).firstOrNull !=
              (before?['pending'] as List? ?? []).firstOrNull) {
            cue = 'turn';
          }
        }
      }
    }
    _previous = room;
    if (cue != null) unawaited(GameAudio.instance.play(cue));
  }

  void dispose() => controller.removeListener(_changed);
}
