import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/brand.dart';
import '../core/audio/game_audio.dart';

bool reducedMotion(BuildContext context) =>
    GameAudio.instance.reduceMotion ||
    MediaQuery.disableAnimationsOf(context) ||
    MediaQuery.of(context).accessibleNavigation;

/// Finite entrances settle completely; server snapshots never restart the motion.
class Enter extends StatelessWidget {
  final Widget child;
  final int milliseconds;
  final double distance;
  const Enter({
    super.key,
    required this.child,
    this.milliseconds = 650,
    this.distance = 22,
  });
  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: milliseconds),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, distance * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

class PressFeedback extends StatefulWidget {
  final Widget child;
  const PressFeedback({super.key, required this.child});
  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) {
      GameAudio.instance.tap();
      setState(() => pressed = true);
    },
    onPointerUp: (_) => setState(() => pressed = false),
    onPointerCancel: (_) => setState(() => pressed = false),
    child: AnimatedScale(
      scale: pressed && !reducedMotion(context) ? .97 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}

class AmbientBackground extends StatelessWidget {
  final Widget child;
  const AmbientBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(.8, -.85),
        radius: 1.45,
        colors: [Color(0xff163c38), Color(0xff0c2023), Color(0xff080f17)],
        stops: [0, .45, 1],
      ),
    ),
    child: child,
  );
}

class CardEmblem extends StatelessWidget {
  final bool compact;
  const CardEmblem({super.key, this.compact = false});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: compact ? 115 : 176,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: reducedMotion(context) ? 0 : 1200),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: compact ? 112 : 178,
              height: compact ? 112 : 178,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xffe7c788).withValues(alpha: .13),
                ),
                gradient: RadialGradient(
                  colors: [
                    const Color(0xff4b7b60).withValues(alpha: .28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            for (var i = -1; i <= 1; i++)
              Transform.translate(
                offset: Offset(
                  i * (compact ? 27 : 40) * t,
                  i == 0 ? -9 * t : 7,
                ),
                child: Transform.rotate(
                  angle: i * .24 * t,
                  child: Container(
                    width: compact ? 61 : 84,
                    height: compact ? 88 : 120,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: i == 0
                            ? [const Color(0xfffff8e7), const Color(0xffe5d3af)]
                            : [
                                const Color(0xff24453f),
                                const Color(0xff142e31),
                              ],
                      ),
                      border: Border.all(
                        color: const Color(0xffd7b77b),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i == 0 ? 'A' : '✦',
                          style: TextStyle(
                            color: i == 0
                                ? const Color(0xff27342f)
                                : const Color(0xffe6c887),
                            fontSize: compact ? 13 : 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              i == 0 ? '♠' : '◇',
                              style: TextStyle(
                                fontSize: compact ? 32 : 48,
                                color: i == 0
                                    ? const Color(0xff243c35)
                                    : const Color(0xffd4ba7a),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: AmbientBackground(
      child: SizedBox.expand(
        child: Center(
          child: Enter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 120),
                const SizedBox(height: 28),
                const Text(
                  Brand.name,
                  style: TextStyle(
                    fontSize: 31,
                    letterSpacing: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xfff2dfb9),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'GOOD CARDS. GREAT COMPANY.',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2.8,
                    color: Color(0xff92b2a5),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 100,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(
                      milliseconds: reducedMotion(context) ? 0 : 1400,
                    ),
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 2,
                      color: const Color(0xffe5bc73),
                      backgroundColor: Colors.white10,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Getting your table ready',
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class TurnClock extends StatelessWidget {
  final int seconds;
  final double fraction;
  const TurnClock({super.key, required this.seconds, required this.fraction});
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$seconds seconds remaining',
    child: SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: fraction.clamp(0, 1)),
            duration: Duration(milliseconds: reducedMotion(context) ? 0 : 350),
            builder: (context, value, _) => SizedBox.expand(
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 3,
                backgroundColor: Colors.white10,
                color: seconds <= 5
                    ? const Color(0xfff49986)
                    : const Color(0xffe5bc73),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: Duration(
                  milliseconds: reducedMotion(context) ? 0 : 180,
                ),
                child: Text(
                  '$seconds',
                  key: ValueKey(seconds),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Text(
                'SEC',
                style: TextStyle(
                  fontSize: 8,
                  letterSpacing: 1.5,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class VictoryEmblem extends StatelessWidget {
  const VictoryEmblem({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 130,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: reducedMotion(context) ? 0 : 1900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        painter: _CelebrationPainter(reducedMotion(context) ? .75 : t),
        child: Center(
          child: Transform.scale(
            scale: .65 + .35 * t,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xffe8c78c), Color(0xff9b733b)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xffe5bc73).withValues(alpha: .2),
                    blurRadius: 35,
                  ),
                ],
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xff24352f),
                size: 48,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CelebrationPainter extends CustomPainter {
  final double progress;
  _CelebrationPainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 28; i++) {
      final angle = i * math.pi * 2 / 28;
      final distance = 28 + progress * (45 + (i % 5) * 11);
      final center = Offset(
        size.width / 2 + math.cos(angle) * distance * 1.4,
        size.height / 2 + math.sin(angle) * distance * .6,
      );
      final paint = Paint()
        ..color = [
          const Color(0xffe5bc73),
          const Color(0xff87cdb0),
          const Color(0xfff3e3bf),
        ][i % 3].withValues(alpha: (1 - progress * .75).clamp(0, 1));
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle + progress * 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-2, -4, 4, 8),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Cosmetic overlay: never handles inputs or changes game clocks/cards.
class DealFlight extends StatelessWidget {
  final int seats;
  const DealFlight({super.key, required this.seats});
  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 700 + seats * 100),
        builder: (context, t, _) =>
            CustomPaint(painter: _DealPainter(t, seats), size: Size.infinite),
      ),
    );
  }
}

class _DealPainter extends CustomPainter {
  final double progress;
  final int seats;
  _DealPainter(this.progress, this.seats);
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < seats; i++) {
      final t = ((progress - i * .045) / .5).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      final eased = Curves.easeInOutCubic.transform(t);
      final angle = i * math.pi * 2 / seats;
      final pos = Offset(
        size.width / 2 + math.sin(angle) * (size.width / 2 - 50) * eased,
        size.height / 2 - math.cos(angle) * (size.height / 2 - 52) * eased,
      );
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle * eased);
      final rect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-13, -19, 26, 38),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, Paint()..color = const Color(0xff214c46));
      canvas.drawRRect(
        rect,
        Paint()
          ..color = const Color(0xffedce94)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        Offset.zero,
        5,
        Paint()..color = const Color(0xffedce94),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_DealPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.seats != seats;
}
