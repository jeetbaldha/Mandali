import 'dart:async';

import 'package:uuid/uuid.dart';

import '../core/game_client.dart';
import '../game/controllers/game_controller.dart';

class SoloController extends GameController {
  final GameClient online;
  @override
  Json? room;
  @override
  bool busy = false;
  String? error;
  int clockOffset = 0;
  bool _disposed = false;
  int _syncGeneration = 0;
  bool _wasConnected = false;
  dynamic _boundSocket;
  late final void Function(dynamic) _onState;
  SoloController(this.online) {
    _onState = (dynamic value) => accept(Json.from(value as Map));
    online.addListener(_connectionChanged);
    _connectionChanged();
  }
  @override
  Json? get user => online.user;
  @override
  bool get connected => online.connected;
  @override
  int get now => DateTime.now().millisecondsSinceEpoch + clockOffset;
  void _connectionChanged() {
    if (_boundSocket != online.socket) {
      _boundSocket?.off('practice:state', _onState);
      _boundSocket = online.socket;
      _boundSocket?.on('practice:state', _onState);
    }
    if (connected && !_wasConnected) unawaited(sync());
    if (_wasConnected != connected) _notify();
    _wasConnected = connected;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void accept(Json incoming) {
    if (_disposed || incoming['ownerId'] != selfId) return;
    if (room?['id'] == incoming['id'] &&
        (room?['version'] ?? -1) > incoming['version']) {
      return;
    }
    clockOffset =
        (incoming['serverTime'] as int) - DateTime.now().millisecondsSinceEpoch;
    room = incoming;
    error = null;
    _notify();
  }

  Future<void> sync() async {
    if (online.token == null) return;
    final generation = ++_syncGeneration;
    final token = online.token;
    final previousRoom = room;
    bool isCurrent() =>
        !_disposed &&
        generation == _syncGeneration &&
        token == online.token &&
        identical(room, previousRoom);
    try {
      final data = await online.request('/practice');
      // Socket updates or newer requests take precedence over this refresh.
      if (!isCurrent()) return;
      if (data != null) {
        accept(Json.from(data));
      } else {
        room = null;
        _notify();
      }
    } catch (e) {
      if (!isCurrent()) return;
      error = '$e';
      _notify();
    }
  }

  Future<void> start(Json settings) async {
    if (busy) return;
    busy = true;
    _notify();
    try {
      accept(
        Json.from(
          await online.request(
            '/practice/start',
            body: {'commandId': const Uuid().v4(), 'settings': settings},
          ),
        ),
      );
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  Future<void> command(String event, [Json payload = const {}]) async {
    if (busy || room == null) return;
    if (!connected) {
      throw Exception('Reconnecting. Please wait before playing.');
    }
    final Json command = switch (event) {
      'game:start' => {'type': 'NEXT'},
      'balance:add' => {'type': 'BALANCE_ADD', 'amount': payload['amount']},
      'game:see' => {
        'type': 'ACTION',
        'action': {'type': 'SEE'},
      },
      _ => {
        'type': 'ACTION',
        'action': {
          'type': payload['action'],
          if (payload['amount'] != null) 'amount': payload['amount'],
        },
      },
    };
    final body = {
      'commandId': const Uuid().v4(),
      'sessionId': room!['id'],
      'version': room!['version'],
      'command': command,
    };
    busy = true;
    _notify();
    try {
      dynamic data;
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          data = await online.request('/practice/command', body: body);
          break;
        } on TimeoutException {
          if (attempt == 1) rethrow;
        }
      }
      accept(Json.from(data));
    } catch (_) {
      await sync();
      rethrow;
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  Future<void> disconnectRoom() async {
    /* Practice is persisted; navigation owns leaving the view. */
  }
  @override
  void dispose() {
    _disposed = true;
    online.removeListener(_connectionChanged);
    _boundSocket?.off('practice:state', _onState);
    super.dispose();
  }
}
