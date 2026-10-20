import 'package:card_game_flutter_application/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:card_game_flutter_application/core/game_client.dart';
import 'package:card_game_flutter_application/core/voice_controller.dart';
import 'package:card_game_flutter_application/ui/shell.dart';
import 'package:card_game_flutter_application/ui/table.dart';
import 'package:card_game_flutter_application/ui/motion.dart';
import 'package:card_game_flutter_application/ui/widgets.dart';

void main() {
  testWidgets('Decorative motion settles and honors reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              CardEmblem(),
              VictoryEmblem(),
              SizedBox(height: 200, child: DealFlight(seats: 10)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Column(
              children: [
                Enter(child: Text('Ready')),
                CardEmblem(),
                PlayingCard(),
                SizedBox(height: 100, child: DealFlight(seats: 6)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Ready'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Guest entry is responsive and clearly virtual-only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    final client = GameClient()..loading = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: mandaliTheme(),
        home: GameShell(client: client),
      ),
    );
    expect(find.text('Your people. Your table.'), findsOneWidget);
    expect(find.text('VIRTUAL POINTS ONLY  ·  NO CASH VALUE'), findsOneWidget);
    expect(find.text('Enter as guest  →'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    client.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  for (final count in [3, 6, 10]) {
    testWidgets('Table renders $count seats and hidden cards at mobile width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      final client = GameClient()
        ..loading = false
        ..connected = true
        ..user = {'id': 'p0', 'name': 'Jeet'};
      client.room = {
        'id': 'room',
        'name': 'Friends',
        'code': 'GJ82K9',
        'hostId': 'p0',
        'version': 1,
        'settings': {'increment': 20},
        'presence': {},
        'players': List.generate(
          count,
          (i) => {
            'id': 'p$i',
            'name': 'Friend $i',
            'avatar': 'kite',
            'balance': 500,
            'active': true,
          },
        ),
        'game': {
          'id': 'hand',
          'phase': 'DECISION',
          'dealerId': 'p0',
          'round': 1,
          'call': 20,
          'pot': 0,
          'cardCount': 3,
          'endTime': DateTime.now().millisecondsSinceEpoch + 15000,
          'pending': ['p0'],
          'ballots': [],
          'players': List.generate(
            count,
            (i) => {
              'id': 'p$i',
              'folded': false,
              'seen': false,
              'blind': false,
              'cards': [],
              'contributed': 0,
              'added': 0,
            },
          ),
        },
      };
      final voice = VoiceController(client);
      await tester.pumpWidget(
        MaterialApp(
          theme: mandaliTheme(),
          home: Scaffold(
            body: GameTable(
              client: client,
              voice: voice,
              onCommand: (_, _) async {},
              onAddBalance: () {},
              onLobbySettings: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('VIRTUAL POT'), findsOneWidget);
      expect(find.text('YOUR HAND · HIDDEN'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      voice.dispose();
      client.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }
}
