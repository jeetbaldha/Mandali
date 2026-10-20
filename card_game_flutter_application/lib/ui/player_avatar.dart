import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/brand.dart';

/// Geometric table badges inspired by kites, lotus petals and woven rosettes.
class PlayerAvatar extends StatelessWidget {
  final String kind;
  final double size;
  const PlayerAvatar({super.key, required this.kind, this.size = 36});
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$kind avatar',
    image: true,
    child: CustomPaint(size: Size.square(size), painter: _AvatarPainter(kind)),
  );
}

class _AvatarPainter extends CustomPainter {
  final String kind;
  _AvatarPainter(this.kind);
  @override
  void paint(Canvas canvas, Size size) {
    const styles = {
      'peacock': (6, Color(0xff79b7a4)),
      'lion': (8, Color(0xffe5bc73)),
      'lotus': (5, Color(0xffd59b8c)),
      'kite': (4, Color(0xffb7c8d2)),
      'sun': (10, Color(0xffe6c991)),
      'moon': (3, Color(0xffc6b5d9)),
    };
    final style = styles[kind] ?? styles['kite']!;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / 40);
    canvas.drawCircle(
      Offset.zero,
      19,
      Paint()..color = const Color(0xff142824),
    );
    canvas.drawCircle(
      Offset.zero,
      18,
      Paint()
        ..color = style.$2.withValues(alpha: .5)
        ..style = PaintingStyle.stroke,
    );
    for (var i = 0; i < style.$1; i++) {
      canvas.drawPath(
        Path()
          ..moveTo(0, -14)
          ..quadraticBezierTo(8, -7, 0, -3)
          ..quadraticBezierTo(-8, -7, 0, -14),
        Paint()..color = style.$2,
      );
      canvas.rotate(math.pi * 2 / style.$1);
    }
    canvas.drawCircle(Offset.zero, 2.2, Paint()..color = Brand.ivory);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AvatarPainter oldDelegate) => oldDelegate.kind != kind;
}
