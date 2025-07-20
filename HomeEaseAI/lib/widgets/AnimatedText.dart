import 'package:flutter/material.dart';

class AnimatedTextSwitcher extends StatefulWidget {
  final List<Widget> texts; // 🔄 Now accepts styled Text widgets!
  final Duration switchDuration;
  final Duration animationDuration;
  final double fixedHeight;
  final Alignment alignment;

  const AnimatedTextSwitcher({
    super.key,
    required this.texts,
    this.switchDuration = const Duration(seconds: 3),
    this.animationDuration = const Duration(milliseconds: 600),
    this.fixedHeight = 80,
    this.alignment = Alignment.centerLeft,
  });

  @override
  State<AnimatedTextSwitcher> createState() => _AnimatedTextSwitcherState();
}

class _AnimatedTextSwitcherState extends State<AnimatedTextSwitcher> {
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startSwitching();
  }

  void _startSwitching() {
    Future.delayed(widget.switchDuration, () {
      if (!mounted) return;
      setState(() {
        currentIndex = (currentIndex + 1) % widget.texts.length;
      });
      _startSwitching();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.fixedHeight,
      child: AnimatedSwitcher(
        duration: widget.animationDuration,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: Align(
          alignment: widget.alignment,
          key: ValueKey(currentIndex), // 🔑 Unique key to trigger animation
          child: widget.texts[currentIndex],
        ),
      ),
    );
  }
}
