import 'package:flutter/material.dart';

class VipMessageEntry extends StatelessWidget {
  final Widget child;
  final int index; // نستخدم الترتيب لتأخير الحركة قليلاً
  final bool isUser;

  const VipMessageEntry({
    super.key,
    required this.child,
    required this.index,
    this.isUser = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 600), // مدة الحركة
      curve: Curves.easeOutCubic, // أهم جزء! منحنى حركة ناعم جداً
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          // الرسالة تأتي من الأسفل (50 بكسل) إلى مكانها (0)
          // If user, maybe slide from right? For now let's stick to user request (up slide)
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value, // تظهر تدريجياً
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
