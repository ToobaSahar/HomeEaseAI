// lib/widgets/background_painter.dart

import 'package:flutter/material.dart';

class BackgroundPainter extends CustomPainter {
  final double waveValue;

  BackgroundPainter(this.waveValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.blueGrey.shade900,
          Colors.blueGrey.shade700,
          Colors.blueGrey.shade500,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
