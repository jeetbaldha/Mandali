import 'package:card_game_flutter_application/ui/theme.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:card_game_flutter_application/core/game_client.dart';
import 'package:card_game_flutter_application/ui/shell.dart';

Future<void> eventually(bool Function() predicate) async {
  final end = DateTime.now().add(const Duration(seconds: 30));
  while (!predicate()) {
    if (DateTime.now().isAfter(end)) {
      throw TimeoutException('Waiting for multiplayer state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Emulator plays a real three-player hand through hidden voting and Draw',
    (tester) async {
      final clients = List.generate(3, (_) => GameClient()..loading = false);
      final host = clients.first;
      final previousRoom = await host.storage.read(key: 'roomId');
      try {
        for (var i = 0; i < clients.length; i++) {
          final client = clients[i];
          final session = await client.request(
            '/session/guest',
            body: {'name': 'Emulator QA ${i + 1}', 'avatar': 'kite'},
          );
          client.token = session['token'];
          client.user = Json.from(session['user']);
          client.connect();
          await eventually(() => client.connected);
        }
        await tester.pumpWidget(
          MaterialApp(
            theme: mandaliTheme(),
            home: GameShell(client: host),
          ),
        );
        await host.command('room:create', {'name': 'Emulator validation'});
        await eventually(() => host.room != null);
        for (final client in clients.skip(1)) {
          await client.command('room:join', {'code': host.room!['code']});
        }
        await eventually(() => host.players.length == 3);
        await tester.pumpAndSettle();
        expect(find.text('3 / 10 friends'), findsOneWidget);
        await host.command('room:configure', {
          'settings': {
            ...Json.from(host.room!['settings']),
            'showAfter': 1,
            'reviewSeconds': 15,
          },
          'activeIds': clients.map((c) => c.selfId).toList(),
        });
        await host.command('game:start');
        await host.command('game:deal', {'cardCount': 3});
        await eventually(
          () => clients.every((c) => c.game?['phase'] == 'DECISION'),
        );
        expect(host.handPlayer!['cards'], isEmpty);
        for (final client in clients) {
          await eventually(
            () =>
                (client.game!['pending'] as List).firstOrNull == client.selfId,
          );
          await client.command('game:action', {'action': 'PLAY'});
        }
        await eventually(() => host.game!['phase'] == 'SHOW_CHOICE');
        expect(host.game!['pot'], 60);
        expect(host.me!['balance'], 480);
        await host.command('game:action', {'action': 'SHOW'});
        await eventually(() => host.game!['phase'] == 'REVEAL');
        expect(
          (host.game!['players'] as List).every(
            (p) => (p['cards'] as List).length == 3,
          ),
          isTrue,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await eventually(
          () => clients.every((c) => c.game!['phase'] == 'VOTING'),
        );
        await clients[0].command('show:vote', {'choice': 'DRAW'});
        await eventually(
          () => clients[1].room!['version'] == clients[0].room!['version'],
        );
        await clients[1].command('show:vote', {'choice': 'DRAW'});
        await eventually(
          () => clients[2].room!['version'] == clients[1].room!['version'],
        );
        await clients[2].command('show:vote', {'choice': 'ABSTAIN'});
        expect((host.game!['ballots'] as List).last['counts'], isNull);
        await eventually(() => host.game!['phase'] == 'RESULT');
        expect(host.game!['result']['kind'], 'DRAW');
        expect(host.me!['balance'], 500);
        final history = await host.request('/history') as List;
        expect(history.first['result']['pot'], 60);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Leaving a finished hand must not crash the other players' result view.
        await clients[2].command('room:leave');
        await eventually(() => host.players.length == 2);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final client in clients.take(2)) {
          await client.command('room:leave');
        }
      } finally {
        await tester.pumpWidget(const SizedBox());
        for (final client in clients) {
          client.dispose();
        }
        if (previousRoom == null) {
          await host.storage.delete(key: 'roomId');
        } else {
          await host.storage.write(key: 'roomId', value: previousRoom);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
