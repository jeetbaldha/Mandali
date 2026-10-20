import 'package:flutter/material.dart';

import 'dart:math' as math;

import 'motion.dart';
import '../core/theme/brand.dart';

const gold = Color(0xffe5bc73);
const mint = Color(0xff75c8ac);
const avatars = {
  'peacock': '🦚',
  'lion': '🦁',
  'lotus': '🪷',
  'kite': '🪁',
  'sun': '☀️',
  'moon': '🌙',
};

class GameButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  const GameButton({super.key, required this.onPressed, required this.child});
  @override
  Widget build(BuildContext context) => PressFeedback(
    child: FilledButton(onPressed: onPressed, child: child),
  );
}

class Panel extends StatelessWidget {
  final Widget child;
  const Panel({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff1a3637), Color(0xff102427)],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xff658777).withValues(alpha: .22)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x24000000),
          blurRadius: 20,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionTitle(this.title, {super.key, this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              subtitle!,
              style: const TextStyle(color: Color(0xffa4bab7), height: 1.5),
            ),
          ),
      ],
    ),
  );
}

class PlayingCard extends StatelessWidget {
  final Map<String, dynamic>? card;
  final double width;
  final bool selected;
  final bool highlighted;
  final VoidCallback? onTap;
  const PlayingCard({super.key, this.card, this.width = 52, this.selected = false, this.highlighted = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    const suits = {'S': '♠', 'H': '♥', 'D': '♦', 'C': '♣'};
    final red = card?['suit'] == 'H' || card?['suit'] == 'D';
    return Semantics(label: card == null ? 'Hidden playing card' : '${card!['rank']} of ${const {'S':'spades','H':'hearts','D':'diamonds','C':'clubs'}[card!['suit']]}', selected: selected, button: onTap != null,
      child: GestureDetector(onTap: onTap, child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: reducedMotion(context) ? 0 : 550),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Transform.translate(
        offset: Offset(0, 24 * (1 - progress) - (selected ? 8 : 0)),
        child: Opacity(opacity: progress, child: child),
      ),
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: reducedMotion(context) ? 0 : 450),
        transitionBuilder: (child, animation) => AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .001)
              ..rotateY((1 - animation.value) * math.pi / 2),
            child: child,
          ),
        ),
        child: Container(
          key: ValueKey(card?['id'] ?? 'hidden'),
          width: width,
          height: width * 1.4,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: card == null
                ? const Color(0xff213b46)
                : const Color(0xfff9f3e7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: highlighted || selected ? gold : gold.withValues(alpha: .6), width: highlighted || selected ? 2.5 : 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 7,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (card == null)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: gold.withValues(alpha: .3)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              if (card != null)
                Positioned(
                  top: 4,
                  left: 5,
                  child: Text(
                    '${card!['rank']}',
                    style: TextStyle(
                      fontSize: width * .16,
                      fontWeight: FontWeight.w800,
                      color: red
                          ? const Color(0xffb84446)
                          : const Color(0xff132a2a),
                    ),
                  ),
                ),
              if (card != null)
                Positioned(bottom: 4, right: 5, child: RotatedBox(quarterTurns: 2, child: Text('${card!['rank']}', style: TextStyle(fontSize: width * .16, fontWeight: FontWeight.w800, color: red ? Brand.vermilion : Brand.ink)))),
              Center(
                child: card == null ? BrandMark(size: width * .7) : Text(
                  '${suits[card!['suit']]}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: width * .5,
                    fontWeight: FontWeight.w800,
                    color: card == null
                        ? gold
                        : red
                        ? const Color(0xffb84446)
                        : const Color(0xff132a2a),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    )));
  }
}
