import 'dart:async';

import 'package:flutter/material.dart';

import '../game/controllers/game_controller.dart';
import 'motion.dart';
import '../core/audio/game_audio.dart';

/// Only this small subtree ticks; the table and networking controllers do not.
class LiveTurnClock extends StatefulWidget {
  final GameController controller;
  const LiveTurnClock({super.key, required this.controller});
  @override
  State<LiveTurnClock> createState() => _LiveTurnClockState();
}

class _LiveTurnClockState extends State<LiveTurnClock> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.controller.seconds == 3 &&
          (widget.controller.game?['pending'] as List? ?? []).firstOrNull ==
              widget.controller.selfId) {
        unawaited(GameAudio.instance.play('timer'));
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, g = c.game!;
    final duration =
        (((g['endTime'] as num) -
                    ((g['startTime'] as num?) ??
                        (g['endTime'] as num) - 15000)) /
                1000)
            .clamp(1, 1000);
    return TurnClock(
      seconds: c.seconds,
      fraction: (c.seconds / duration).clamp(0, 1),
    );
  }
}
