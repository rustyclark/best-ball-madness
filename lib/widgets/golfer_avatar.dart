import 'package:flutter/material.dart';
import 'package:best_ball_madness/models/draft_models.dart';
import 'package:best_ball_madness/theme/colors.dart';

class GolferAvatar extends StatelessWidget {
  final GolferProfile profile;
  final double size;

  const GolferAvatar({Key? key, required this.profile, this.size = 40})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Generate initials for the fallback text
    final nameParts = profile.name.trim().split(' ');
    String initials = '';
    if (nameParts.isNotEmpty) {
      if (nameParts.length > 1) {
        initials = '${nameParts.first[0]}${nameParts.last[0]}'.toUpperCase();
      } else {
        initials = nameParts.first[0].toUpperCase();
      }
    }

    final fallback = CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primary.withOpacity(0.1),
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.35,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 1),
        color: Colors.white,
      ),
      child: ClipOval(
        child: Image.network(
          profile.headshotUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return fallback;
          },
        ),
      ),
    );
  }
}
