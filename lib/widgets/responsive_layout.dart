import 'package:flutter/material.dart';
import '../theme/colors.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final Widget? appBar;
  final Widget? bottomNavigationBar;
  final double maxWidth;

  const ResponsiveLayout({
    super.key,
    required this.child,
    this.appBar,
    this.bottomNavigationBar,
    this.maxWidth = 500.0, // Center and constrain on wider screens
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 768) {
            // Desktop/Tablet constrained layout with premium background
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D1117), Color(0xFF06090D)],
                ),
              ),
              child: Center(
                child: Container(
                  width: maxWidth,
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Scaffold(
                    appBar: appBar != null
                        ? _buildPreferredSizeAppBar(appBar!)
                        : null,
                    backgroundColor: AppColors.background,
                    body: child,
                    bottomNavigationBar: bottomNavigationBar,
                  ),
                ),
              ),
            );
          } else {
            // Standard mobile view
            return Scaffold(
              appBar: appBar != null
                  ? _buildPreferredSizeAppBar(appBar!)
                  : null,
              backgroundColor: AppColors.background,
              body: child,
              bottomNavigationBar: bottomNavigationBar,
            );
          }
        },
      ),
    );
  }

  PreferredSizeWidget _buildPreferredSizeAppBar(Widget bar) {
    if (bar is PreferredSizeWidget) return bar;
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: bar,
    );
  }
}
