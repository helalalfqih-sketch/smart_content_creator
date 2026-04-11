import 'dart:ui';
import 'package:flutter/material.dart';

class SmartCard extends StatefulWidget {
  final Widget child;
  final bool active;
  final VoidCallback? onTap;
  final Duration hoverDuration;

  const SmartCard({
    super.key,
    required this.child,
    this.active = false,
    this.onTap,
    this.hoverDuration = const Duration(milliseconds: 150),
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                  border: Border.all(
                    color: widget.active
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.5)
                        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                    width: widget.active ? 2 : 1,
                  ),
                  boxShadow: widget.active
                      ? [
                          BoxShadow(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                padding: const EdgeInsets.all(16),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
