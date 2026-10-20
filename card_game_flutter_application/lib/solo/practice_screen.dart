import 'dart:async';

import 'package:flutter/material.dart';

import '../core/game_client.dart';
import '../ui/table.dart';
import '../ui/widgets.dart';
import 'solo_controller.dart';
import '../core/audio/table_audio.dart';
import '../core/audio/game_audio.dart';

class PracticeScreen extends StatefulWidget {
  final SoloController controller;
  const PracticeScreen({super.key, required this.controller});
  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late final TableAudio audio;
  @override
  void initState() {
    super.initState();
    audio = TableAudio(widget.controller);
    unawaited(GameAudio.instance.play('room_joined'));
  }

  @override
  void dispose() {
    audio.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      unawaited(GameAudio.instance.play('error'));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> addBalance() async {
    final input = TextEditingController(text: '500');
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modify virtual balance'),
        content: TextField(
          controller: input,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Add virtual points · no cash value',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(input.text)),
            child: const Text('Add points'),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(seconds: 1), input.dispose);
    if (amount != null) {
      await run(
        () => widget.controller.command('balance:add', {'amount': amount}),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Practice table')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final c = widget.controller;
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  'SOLO · Game-controlled participants · Virtual points only',
                  style: TextStyle(fontSize: 11, color: gold),
                ),
              ),
              if (!c.connected)
                const ListTile(
                  leading: Icon(Icons.wifi_off),
                  title: Text('Reconnecting…'),
                  subtitle: Text('Your practice hand is saved.'),
                ),
              if (c.error != null)
                Text(
                  c.error!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              Expanded(
                child: c.game == null
                    ? const Center(child: Text('Loading your saved table…'))
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1050),
                          child: GameTable(
                            key: ValueKey(c.game!['id']),
                            client: c,
                            onCommand: (String event, Json payload) =>
                                run(() => c.command(event, payload)),
                            onAddBalance: addBalance,
                            onLobbySettings: () {},
                            onLeave: () => Navigator.pop(context),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
