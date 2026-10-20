import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';
import 'widgets.dart';

class FeltSurface extends StatelessWidget {
  const FeltSurface({super.key});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(500),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xffb59767), Color(0xff3e382d), Color(0xff8e7956)],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x90000000),
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
        BoxShadow(color: Color(0x1526dba1), blurRadius: 36),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(7),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(500),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-.25, -.3),
              radius: 1,
              colors: [Color(0xff276852), Color(0xff124437), Color(0xff0d2b28)],
            ),
          ),
          child: CustomPaint(painter: _FeltPattern()),
        ),
      ),
    ),
  );
}

class _FeltPattern extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dots = Paint()..color = const Color(0x126ef0b1);
    for (double y = 0; y < size.height; y += 13) {
      for (double x = 0; x < size.width; x += 13) {
        canvas.drawCircle(Offset(x + (y ~/ 13 % 2) * 6, y), .65, dots);
      }
    }
    final edge = RRect.fromRectAndRadius(
      Rect.fromLTWH(10, 10, size.width - 20, size.height - 20),
      const Radius.circular(500),
    );
    canvas.drawRRect(
      edge,
      Paint()
        ..color = const Color(0x507caf88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      math.min(size.width, size.height) * .29,
      Paint()
        ..color = const Color(0x1674b68e)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_FeltPattern oldDelegate) => false;
}

class AnimatedPot extends StatelessWidget {
  final int value;
  final int call;
  final bool compact;
  const AnimatedPot({
    super.key,
    required this.value,
    required this.call,
    required this.compact,
  });
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Enter(
        key: ValueKey(value),
        distance: -10,
        milliseconds: 480,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: gold.withValues(alpha: .12),
            border: Border.all(color: gold.withValues(alpha: .4)),
          ),
          child: const Icon(Icons.toll_rounded, size: 18, color: gold),
        ),
      ),
      const SizedBox(height: 9),
      const Text(
        'VIRTUAL POT',
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 2.2,
          color: Color(0xffa4c3ae),
        ),
      ),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? 120 : 170),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.toDouble()),
          duration: Duration(milliseconds: reducedMotion(context) ? 0 : 650),
          curve: Curves.easeOutCubic,
          builder: (context, number, _) => FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${number.round()}',
              style: TextStyle(
                fontSize: compact ? 36 : 46,
                height: 1.2,
                color: const Color(0xffffe3ad),
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Call $call points',
          style: const TextStyle(fontSize: 10, color: Color(0xffc9d7c9)),
        ),
      ),
    ],
  );
}

class PhaseRibbon extends StatelessWidget {
  final String phase;
  final int round;
  const PhaseRibbon({super.key, required this.phase, required this.round});
  @override
  Widget build(BuildContext context) {
    final label = switch (phase) {
      'WAITING_DEAL' => 'THE NEXT HAND AWAITS',
      'DECISION' => 'MAKE YOUR MOVE',
      'SHOW_CHOICE' => 'SHOW OR KEEP PLAYING',
      'REVEAL' => 'ALL EYES ON THE CARDS',
      'VOTING' => 'YOUR VOTE. THEIR VICTORY.',
      'RESULT' => 'A HAND WELL PLAYED',
      _ => 'TAKE A BREATHER',
    };
    return Enter(
      key: ValueKey('$phase-$round'),
      distance: 8,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: gold.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: gold.withValues(alpha: .14)),
        ),
        child: Row(
          children: [
            Icon(
              phase == 'VOTING'
                  ? Icons.how_to_vote_outlined
                  : phase == 'RESULT'
                  ? Icons.emoji_events_outlined
                  : Icons.auto_awesome,
              color: gold,
              size: 15,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  color: gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
