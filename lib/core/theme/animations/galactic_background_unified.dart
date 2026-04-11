import 'package:flutter/material.dart';

/// 🌌 GalacticBackgroundUnified - A high-performance, reusable animated background
/// with nebulae and stars. Used across Splash, Login, and Dashboards.
class GalacticBackgroundUnified extends StatelessWidget {
  final Animation<double>? animation;
  final Color baseColor;
  final double starOpacity;

  const GalacticBackgroundUnified({
    super.key,
    this.animation,
    this.baseColor = const Color(0xFF030303),
    this.starOpacity = 0.2,
  });

  @override
  Widget build(BuildContext context) {
    // If no animation is provided, we use a static value or a local controller
    final animValue = animation?.value ?? 0.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Dark Base
        Container(color: baseColor),

        // 2. Dynamic Nebulae
        Positioned(
          top: -100 + (animValue * 20),
          left: -50,
          child: _Nebula(
            color: Colors.cyanAccent.withValues(alpha: 0.1),
            size: 400,
          ),
        ),
        Positioned(
          bottom: -150,
          right: -100 - (animValue * 20),
          child: _Nebula(
            color: Colors.purpleAccent.withValues(alpha: 0.05),
            size: 500,
          ),
        ),

        // 3. Static Star Field
        Opacity(
          opacity: starOpacity,
          child: CustomPaint(
            painter: _StarPainter(),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }
}

class _Nebula extends StatelessWidget {
  final Color color;
  final double size;
  const _Nebula({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    // Fixed seed for consistent star pattern
    for (var i = 0; i < 100; i++) {
      final x = (i * 137.5) % size.width;
      final y = (i * 245.8) % size.height;
      canvas.drawCircle(Offset(x, y), 0.8, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
