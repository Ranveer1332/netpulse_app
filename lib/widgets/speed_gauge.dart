import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

/// The speed gauge widget — a circular arc with gradient stroke.
class SpeedGauge extends StatelessWidget {
  final double speed;
  final double maxSpeed;

  const SpeedGauge({
    super.key,
    required this.speed,
    this.maxSpeed = 150,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = (speed / maxSpeed).clamp(0.0, 1.0);
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(220, 220),
            painter: _GaugePainter(fraction: fraction),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                speed.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  height: 1,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Mbps',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'DOWNLOAD',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDim,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double fraction;
  _GaugePainter({required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const startAngle = 135 * pi / 180;
    const totalSweep = 270 * pi / 180;
    final sweepAngle = totalSweep * fraction;

    // Track
    final trackPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      trackPaint,
    );

    // Value arc with solid color
    if (fraction > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final valuePaint = Paint()
        ..color = AppColors.teal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweepAngle, false, valuePaint);

      // Glow at the end point
      final endAngle = startAngle + sweepAngle;
      final endPoint = Offset(
        center.dx + radius * cos(endAngle),
        center.dy + radius * sin(endAngle),
      );
      final glowPaint = Paint()
        ..color = AppColors.teal.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(endPoint, 6, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.fraction != fraction;
}
