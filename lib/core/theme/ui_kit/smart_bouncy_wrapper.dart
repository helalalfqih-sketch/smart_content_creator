import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ✨ SmartBouncyWrapper - A premium micro-interaction wrapper that adds 
/// a satisfying bounce and haptic response to any widget on tap.
class SmartBouncyWrapper extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;
  final double scaleFactor;
  final Duration duration;
  final bool animate;

  const SmartBouncyWrapper({
    super.key,
    required this.onTap,
    this.onLongPress,
    required this.child,
    this.scaleFactor = 0.97, // 🔥 Refined for Soft UI
    this.duration = const Duration(milliseconds: 150), // 🔥 Smoother SaaS feel
    this.animate = true,
  });

  @override
  State<SmartBouncyWrapper> createState() => _SmartBouncyWrapperState();
}


class _SmartBouncyWrapperState extends State<SmartBouncyWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.animate) {
      _controller.forward();
      HapticFeedback.lightImpact(); 
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.animate) {
      _controller.reverse();
    }
    widget.onTap();
  }

  void _handleTapCancel() {
    if (widget.animate) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: widget.child,
      );
    }

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPress: () {
        if (widget.onLongPress != null) {
          HapticFeedback.mediumImpact();
          widget.onLongPress!();
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.child,
          );
        },
      ),
    );
  }
}
