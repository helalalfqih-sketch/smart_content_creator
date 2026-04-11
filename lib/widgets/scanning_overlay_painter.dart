import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class ScanningOverlay extends StatefulWidget {
  const ScanningOverlay({super.key});

  @override
  State<ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<ScanningOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // ⏱️ زمن الأنيميشن: ثانيتان للنزول وثانيتان للصعود
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), 
    )..repeat(reverse: true); // التكرار صعوداً ونزولاً
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: ScanningOverlayPainter(progress: _controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class ScanningOverlayPainter extends CustomPainter {
  final double progress;

  ScanningOverlayPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final double cornerLength = size.width * 0.15; // طول زاوية التحديد
    final double padding = 20.0; // البعد عن حواف الصورة

    // 1️⃣ رسم زوايا التحديد الأربع (Bounding Box Corners)
    
    // الزاوية العلوية اليسرى
    canvas.drawLine(Offset(padding, padding + cornerLength), Offset(padding, padding), paint);
    canvas.drawLine(Offset(padding, padding), Offset(padding + cornerLength, padding), paint);

    // الزاوية العلوية اليمنى
    canvas.drawLine(Offset(size.width - padding - cornerLength, padding), Offset(size.width - padding, padding), paint);
    canvas.drawLine(Offset(size.width - padding, padding), Offset(size.width - padding, padding + cornerLength), paint);

    // الزاوية السفلية اليسرى
    canvas.drawLine(Offset(padding, size.height - padding - cornerLength), Offset(padding, size.height - padding), paint);
    canvas.drawLine(Offset(padding, size.height - padding), Offset(padding + cornerLength, size.height - padding), paint);

    // الزاوية السفلية اليمنى
    canvas.drawLine(Offset(size.width - padding - cornerLength, size.height - padding), Offset(size.width - padding, size.height - padding), paint);
    canvas.drawLine(Offset(size.width - padding, size.height - padding), Offset(size.width - padding, size.height - padding - cornerLength), paint);

    // 2️⃣ رسم خط الليزر المتحرك (Scanning Line)
    final double scanY = padding + (size.height - padding * 2) * progress;

    final Rect lineRect = Rect.fromCenter(
      center: Offset(size.width / 2, scanY),
      width: size.width - padding * 2,
      height: 3.0,
    );

    // تدرج لوني للخط لجعله يبدو كالليزر (شفاف من الأطراف، صلب من المنتصف)
    final scanPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(padding, scanY),
        Offset(size.width - padding, scanY),
        [
          Colors.transparent,
          Colors.orangeAccent,
          Colors.orangeAccent,
          Colors.transparent,
        ],
      );

    canvas.drawRect(lineRect, scanPaint);

    // 3️⃣ إضافة توهج (Glow) خلف خط الليزر
    final glowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width / 2, scanY - 30),
        Offset(size.width / 2, scanY + 30),
        [
          Colors.transparent,
          Colors.orangeAccent.withValues(alpha: 0.4),
          Colors.transparent,
        ],
      );

    final Rect glowRect = Rect.fromCenter(
      center: Offset(size.width / 2, scanY),
      width: size.width - padding * 2,
      height: 60.0,
    );
    
    canvas.drawRect(glowRect, glowPaint);
  }

  @override
  bool shouldRepaint(covariant ScanningOverlayPainter oldDelegate) {
    return oldDelegate.progress != progress; // إعادة الرسم فقط عند تغير القيمة
  }
}
