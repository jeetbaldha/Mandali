import 'package:flutter/foundation.dart';

typedef Json = Map<String, dynamic>;

/// Shared presentation contract. Rule decisions remain on the authoritative server.
abstract class GameController extends ChangeNotifier {
  Json? get room;
  Json? get user;
  bool get connected;
  bool get busy;
  int get now;
  Json? get game => room?['game'] as Json?;
  String get selfId => user?['id'] as String? ?? '';
  List<Json> get players => (room?['players'] as List? ?? []).cast<Json>();
  Json? get me => players.where((p) => p['id'] == selfId).firstOrNull;
  Json? get handPlayer => (game?['players'] as List? ?? [])
      .cast<Json>()
      .where((p) => p['id'] == selfId)
      .firstOrNull;
  bool get host => room?['hostId'] == selfId;
  bool get solo => room?['mode'] == 'SOLO';
  bool get poker => solo && room?['settings']?['kind'] == 'POKER';
  List<Json> get legalActions =>
      (room?['legalActions'] as List? ?? []).cast<Json>();
  int get seconds => game?['endTime'] == null
      ? 0
      : (((game!['endTime'] as num).toInt() - now) / 1000).ceil().clamp(0, 999);
  Future<void> command(String event, [Json payload = const {}]);
  Future<void> disconnectRoom();
}
