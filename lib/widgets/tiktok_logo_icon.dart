import 'package:flutter/material.dart';

/// Custom TikTok Logo Widget for Fallback UI
class TikTokLogoIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const TikTokLogoIcon({super.key, this.size = 60, this.color});

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Colors.white;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background note icon (musical note shape)
          Positioned(
            left: size * 0.15,
            top: size * 0.1,
            child: Icon(
              Icons.music_note_rounded,
              size: size * 0.8,
              color: const Color(0xFF25F4EE), // TikTok cyan
            ),
          ),
          // Foreground note icon (offset for 3D effect)
          Positioned(
            right: size * 0.15,
            bottom: size * 0.1,
            child: Icon(
              Icons.music_note_rounded,
              size: size * 0.8,
              color: const Color(0xFFFE2C55), // TikTok pink/red
            ),
          ),
          // Center white note
          Center(
            child: Icon(
              Icons.music_note_rounded,
              size: size * 0.8,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}
