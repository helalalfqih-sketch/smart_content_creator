import 'package:flutter/material.dart';

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipe;
  final bool isUser;
  final bool enabled;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onSwipe,
    this.isUser = false,
    this.enabled = true,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragExtent = 0;
  static const double _swipeThreshold = 60.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    if (widget.isUser) {
      if (details.primaryDelta! < 0) {
        setState(() {
          _dragExtent += details.primaryDelta!;
        });
      }
    } else {
      if (details.primaryDelta! > 0) {
        setState(() {
          _dragExtent += details.primaryDelta!;
        });
      }
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragExtent.abs() >= _swipeThreshold) {
      widget.onSwipe();
    }
    setState(() {
      _dragExtent = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 💡 نستخدم الترجمة بناءً على السحب
    final horizontalOffset = widget.isUser
        ? (_dragExtent.clamp(-_swipeThreshold, 0.0))
        : (_dragExtent.clamp(0.0, _swipeThreshold));

    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        alignment: widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          // 🏹 أيقونة الرد التي تظهر خلف الفقاعة
          Opacity(
            opacity: (_dragExtent.abs() / _swipeThreshold).clamp(0.0, 1.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Icon(
                Icons.reply_rounded,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          // 💬 فقاعة الدردشة المتحركة
          Transform.translate(
            offset: Offset(horizontalOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
