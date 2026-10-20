import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:uuid/uuid.dart';

import '../game/controllers/game_controller.dart';
export '../game/controllers/game_controller.dart' show Json;

class SessionExpired implements Exception {
  @override
  String toString() => 'Your guest session expired. Please enter again.';
}

class GameClient extends GameController with WidgetsBindingObserver {
  final storage = const FlutterSecureStorage();
  String endpoint = const String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
  String? token;
  @override
  Json? user;
  @override
  Json? room;
  String? roomId;
  String? error;
  bool loading = true;
  @override
  bool connected = false;
  @override
  bool busy = false;
  int clockOffset = 0;
  io.Socket? socket;
  Timer? ticker;
  bool _disposed = false;

  GameClient() {
    WidgetsBinding.instance.addObserver(this);
  }
  void refresh() {
    if (!_disposed) notifyListeners();
  }

  @override
  int get now => DateTime.now().millisecondsSinceEpoch + clockOffset;
  Future<void> initialize() async {
    try {
      endpoint = await storage.read(key: 'endpoint') ?? endpoint;
      token = await storage.read(key: 'token');
      roomId = await storage.read(key: 'roomId');
      final cached = await storage.read(key: 'identity');
      if (token != null && cached != null) user = Json.from(jsonDecode(cached));
      if (token != null) {
        user = Json.from(await request('/session') as Map);
        connect();
      }
    } on SessionExpired catch (e) {
      await logout();
      error = '$e';
    } catch (e) {
      error = '$e';
      if (token != null && user != null) connect();
    }
    loading = false;
    ticker?.cancel();
    // Countdown widgets own their clocks; no whole-screen rebuild every second.
    refresh();
  }

  Future<dynamic> request(String path, {Json? body}) async {
    final uri = Uri.parse('$endpoint$path');
    if (kReleaseMode && uri.scheme != 'https') {
      throw Exception('Release builds require an HTTPS server');
    }
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final response =
        await (body == null
                ? http.get(uri, headers: headers)
                : http.post(uri, headers: headers, body: jsonEncode(body)))
            .timeout(const Duration(seconds: 12));
    final data = jsonDecode(response.body);
    if (response.statusCode == 401) throw SessionExpired();
    if (response.statusCode >= 400) {
      throw Exception(data is Map ? data['error'] : 'Server request failed');
    }
    return data;
  }

  Future<void> login(String name, String avatar) async {
    final data = await request(
      '/session/guest',
      body: {'name': name, 'avatar': avatar},
    );
    token = data['token'];
    user = Json.from(data['user']);
    room = null;
    roomId = null;
    await storage.delete(key: 'roomId');
    error = null;
    await storage.write(key: 'token', value: token);
    await storage.write(key: 'identity', value: jsonEncode(user));
    connect();
    refresh();
  }

  void connect() {
    socket?.dispose();
    socket = io.io(
      endpoint,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .enableForceNew()
          .enableReconnection()
          .setReconnectionDelay(500)
          .setReconnectionDelayMax(5000)
          .build(),
    );
    socket!.onConnect((_) {
      connected = true;
      error = null;
      refresh();
      if (roomId != null) sync();
    });
    socket!.onDisconnect((_) {
      connected = false;
      refresh();
    });
    socket!.onConnectError((e) {
      connected = false;
      error = 'Cannot connect. Check the server address and session. $e';
      refresh();
    });
    socket!.on('game:state', (value) {
      final incoming = Json.from(value as Map);
      if (room != null &&
          room!['id'] == incoming['id'] &&
          (room!['version'] as int) > (incoming['version'] as int)) {
        return;
      }
      room = incoming;
      roomId = incoming['id'];
      clockOffset =
          (incoming['serverTime'] as int) -
          DateTime.now().millisecondsSinceEpoch;
      unawaited(storage.write(key: 'roomId', value: roomId));
      refresh();
    });
    socket!.on('voice:status', (value) {
      final presence = room?['presence'] as Map?;
      if (presence != null) {
        final existing = Json.from(presence[value['playerId']] as Map? ?? {});
        presence[value['playerId']] = {
          ...existing,
          'mic': value['mic'],
          'speaker': value['speaker'],
        };
        refresh();
      }
    });
    socket!.on('server:error', (value) {
      error = '$value';
      refresh();
    });
    socket!.connect();
  }

  void sync() {
    if (!connected || roomId == null) return;
    socket!.emitWithAck(
      'room:sync',
      {'roomId': roomId},
      ack: (value) {
        if (value is Map && value['ok'] != true) {
          error = '${value['error']}';
          refresh();
        }
      },
    );
  }

  @override
  Future<void> command(String event, [Json payload = const {}]) async {
    if (!connected) {
      throw Exception('Reconnecting. Wait before sending an action.');
    }
    if (busy) return;
    busy = true;
    refresh();
    final input = {
      'commandId': const Uuid().v4(),
      if (roomId != null && event != 'room:create' && event != 'room:join')
        'roomId': roomId,
      if (room != null && event != 'room:create' && event != 'room:join')
        'version': room!['version'],
      'payload': payload,
    };
    try {
      // Retry the exact same command ID once on a missing acknowledgment.
      dynamic result;
      for (var attempt = 0; attempt < 2; attempt++) {
        final done = Completer<dynamic>();
        socket!.emitWithAck(
          event,
          input,
          ack: (value) {
            if (!done.isCompleted) done.complete(value);
          },
        );
        try {
          result = await done.future.timeout(const Duration(seconds: 8));
          break;
        } on TimeoutException {
          if (attempt == 1) rethrow;
        }
      }
      if (result is! Map || result['ok'] != true) {
        throw Exception(
          result is Map ? result['error'] : 'Invalid server response',
        );
      }
      if (event == 'room:leave') {
        room = null;
        roomId = null;
        await storage.delete(key: 'roomId');
      } else {
        roomId = result['roomId'];
      }
      error = null;
    } catch (e) {
      sync();
      rethrow;
    } finally {
      busy = false;
      refresh();
    }
  }

  Future<void> resumeRoom(String id) async {
    roomId = id;
    room = null;
    sync();
    refresh();
  }

  @override
  Future<void> disconnectRoom() async {
    if (roomId != null && connected) {
      socket?.emitWithAck('room:disconnect', {'roomId': roomId}, ack: (_) {});
    }
    room = null;
    roomId = null;
    await storage.delete(key: 'roomId');
    refresh();
  }

  Future<void> setEndpoint(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw Exception('Enter a valid server URL');
    }
    if (kReleaseMode && uri.scheme != 'https') {
      throw Exception('Use HTTPS in release builds');
    }
    await logout();
    endpoint = value.trim().replaceAll(RegExp(r'/$'), '');
    await storage.write(key: 'endpoint', value: endpoint);
    refresh();
  }

  Future<void> logout() async {
    socket?.dispose();
    socket = null;
    connected = false;
    token = null;
    user = null;
    room = null;
    roomId = null;
    await storage.delete(key: 'token');
    await storage.delete(key: 'identity');
    await storage.delete(key: 'roomId');
    refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (socket?.connected != true) {
        socket?.connect();
      } else {
        sync();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    ticker?.cancel();
    socket?.dispose();
    super.dispose();
  }
}
