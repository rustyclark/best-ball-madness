import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

class BbmSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const BbmSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppSpacing.borderRadiusSm,
  });

  const BbmSkeleton.circular({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = AppSpacing.borderRadiusRound;

  @override
  State<BbmSkeleton> createState() => _BbmSkeletonState();
}

class _BbmSkeletonState extends State<BbmSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: widget.borderRadius,
            ),
          ),
        );
      },
    );
  }
}
