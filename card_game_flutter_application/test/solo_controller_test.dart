import 'dart:async';

import 'package:card_game_flutter_application/core/game_client.dart';
import 'package:card_game_flutter_application/solo/solo_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class PendingClient extends GameClient {
  final response = Completer<dynamic>();

  @override
  Future<dynamic> request(String path, {Json? body}) => response.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final staleResponse in [null, 'error']) {
    test(
      'A delayed $staleResponse refresh preserves newer practice state',
      () async {
        final client = PendingClient()
          ..token = 'test-token'
          ..user = {'id': 'player'};
        final controller = SoloController(client);
        final pending = controller.sync();
        controller.accept({
          'id': 'new-session',
          'ownerId': 'player',
          'version': 1,
          'serverTime': DateTime.now().millisecondsSinceEpoch,
        });
        if (staleResponse == null) {
          client.response.complete(null);
        } else {
          client.response.completeError(Exception('Old request failed'));
        }
        await pending;
        expect(controller.room?['id'], 'new-session');
        expect(controller.error, isNull);
        controller.dispose();
        client.dispose();
      },
    );
  }
}
