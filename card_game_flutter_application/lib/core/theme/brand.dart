import 'package:flutter/material.dart';
import 'brand_name.dart';

abstract final class Brand {
  static const name = String.fromEnvironment(
    'APP_NAME',
    defaultValue: productName,
  );
  static const tagline = 'A place at the table.';
  static const ink = Color(0xff101b19);
  static const felt = Color(0xff164b3e);
  static const brass = Color(0xffe5bc73);
  static const ivory = Color(0xfff6efdd);
  static const vermilion = Color(0xffb44c39);
}

/// Original vector mark: four kites gathered around a shared table.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 64});
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${Brand.name} emblem',
    image: true,
    child: CustomPaint(size: Size.square(size), painter: const _MarkPainter()),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final line = Paint()
      ..color = Brand.brass
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(const Offset(50, 50), 45, line);
    canvas.translate(50, 50);
    for (var i = 0; i < 4; i++) {
      canvas.drawPath(
        Path()
          ..moveTo(0, -34)
          ..lineTo(12, -17)
          ..lineTo(0, -5)
          ..lineTo(-12, -17)
          ..close(),
        Paint()..color = i.isEven ? Brand.brass : Brand.ivory,
      );
      canvas.rotate(1.5707963268);
    }
    canvas.drawCircle(Offset.zero, 3, Paint()..color = Brand.vermilion);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}
