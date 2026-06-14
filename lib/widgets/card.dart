import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

class BbmCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final bool glassmorphic;
  final BorderSide? borderSide;

  const BbmCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = AppSpacing.edgeInsetsMD,
    this.glassmorphic = false,
    this.borderSide,
  });

  @override
  State<BbmCard> createState() => _BbmCardState();
}

class _BbmCardState extends State<BbmCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final border = widget.borderSide ?? const BorderSide(color: AppColors.border, width: 1);
    
    Widget cardContent = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.glassmorphic 
            ? AppColors.cardBg.withOpacity(0.75) 
            : AppColors.cardBg,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.fromBorderSide(
          _isHovered && widget.onTap != null
              ? border.copyWith(color: AppColors.primary)
              : border,
        ),
      ),
      child: widget.child,
    );

    if (widget.onTap != null) {
      cardContent = MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: AppSpacing.borderRadiusLg,
          splashColor: AppColors.primary.withOpacity(0.1),
          highlightColor: AppColors.primary.withOpacity(0.05),
          child: AnimatedScale(
            scale: _isHovered ? 1.015 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: cardContent,
          ),
        ),
      );
    }

    return cardContent;
  }
}
