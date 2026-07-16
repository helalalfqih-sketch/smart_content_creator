import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SmartCard extends StatefulWidget {
  final Widget child;
  final bool active;
  final VoidCallback? onTap;
  final Duration hoverDuration;
  final EdgeInsetsGeometry? padding;

  const SmartCard({
    super.key,
    required this.child,
    this.active = false,
    this.onTap,
    this.hoverDuration = const Duration(milliseconds: 150),
    this.padding,
  });

  @override
  State<SmartCard> createState() => _SmartCardState();
}

class _SmartCardState extends State<SmartCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: widget.hoverDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _hoverController.forward(),
      onExit: (_) => _hoverController.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              color: AppTheme.surfaceColor,
              border: Border.all(
                color: widget.active
                    ? AppTheme.primary
                    : Colors.white.withValues(alpha: 0.05),
                width: widget.active ? 1.5 : 1,
              ),
              boxShadow: widget.active
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Padding(
                  padding: widget.padding ?? const EdgeInsets.all(16),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

