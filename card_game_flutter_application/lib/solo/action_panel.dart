import 'package:flutter/material.dart';

import '../game/controllers/game_controller.dart';
import '../ui/widgets.dart';

class SoloActionPanel extends StatelessWidget {
  final GameController controller;
  final Future<void> Function(String, Json) onCommand;
  final VoidCallback onAddBalance;
  const SoloActionPanel({
    super.key,
    required this.controller,
    required this.onCommand,
    required this.onAddBalance,
  });
  Future<void> raise(BuildContext context, Json action) async {
    final input = TextEditingController(text: '${action['min']}');
    String? error;
    final value = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(action['label']),
          content: TextField(
            controller: input,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Virtual points · ${action['min']}–${action['max']}',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final n = int.tryParse(input.text);
                if (n == null ||
                    n < action['min'] ||
                    n > action['max'] ||
                    (!controller.poker &&
                        controller.handPlayer?['seen'] == true &&
                        n.isOdd)) {
                  update(() => error = 'Choose a legal whole-point amount');
                  return;
                }
                Navigator.pop(context, n);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    // The route still owns its editable field during its closing animation.
    Future<void>.delayed(const Duration(seconds: 1), input.dispose);
    if (value != null) {
      await onCommand('game:action', {'action': 'RAISE', 'amount': value});
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = controller, turn = c.game!['pending'].firstOrNull;
    final own = turn == c.selfId;
    final insufficient =
        own &&
        !c.poker &&
        !c.legalActions.any((a) => a['type'] == 'BLIND' || a['type'] == 'PLAY');
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            own
                ? 'YOUR TURN'
                : '${c.players.where((p) => p['id'] == turn).firstOrNull?['name'] ?? 'The table'} is deciding…',
            style: const TextStyle(color: gold, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          if (insufficient) ...[
            const Text(
              'Your virtual balance is insufficient to continue this round.',
            ),
            TextButton(
              onPressed: onAddBalance,
              child: const Text('MODIFY VIRTUAL BALANCE'),
            ),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final a in c.legalActions.where((a) => a['type'] != 'SEE'))
                GameButton(
                  onPressed: !c.connected || c.busy || c.seconds <= 0
                      ? null
                      : () => a['type'] == 'RAISE'
                            ? raise(context, a)
                            : onCommand('game:action', {'action': a['type']}),
                  child: Text(
                    '${a['label']}${a['cost'] != null ? ' · ${a['cost']}' : ''}',
                  ),
                ),
            ],
          ),
          if (!own)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Take a moment to read the table.',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          if (c.poker)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Virtual points · balance additions are available between hands.',
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ),
        ],
      ),
    );
  }
}
