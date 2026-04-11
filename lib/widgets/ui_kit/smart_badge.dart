import 'package:flutter/material.dart';

class SmartBadge extends StatelessWidget {
  final bool connected;
  final String? label;

  const SmartBadge({
    super.key,
    required this.connected,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: connected ? Colors.green : Colors.red,
      ),
      child: Text(
        label ?? (connected ? '✓ متصل' : '✗ غير متصل'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'IBMPlexSansArabic',
        ),
      ),
    );
  }
}
