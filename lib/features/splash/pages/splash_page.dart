import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/splash_controller.dart';

class SplashPage extends GetView<SplashController> {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: _SplashBackground(child: _SplashContent()),
    );
  }
}

/// Full-screen gradient background with a subtle central atmospheric glow,
/// matching the Stitch design reference.
class _SplashBackground extends StatelessWidget {
  const _SplashBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A2236), // top — slightly lighter blue-navy
            Color(0xFF10131A), // bottom — deep dark
          ],
        ),
      ),
      child: Stack(
        children: [
          // Subtle central radial glow (the atmospheric blue bloom in Stitch design)
          Positioned.fill(
            child: Center(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF2D4A7A).withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SplashContent extends StatefulWidget {
  const _SplashContent();

  @override
  State<_SplashContent> createState() => _SplashContentState();
}

class _SplashContentState extends State<_SplashContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
          ),
        );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(flex: 3),
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: const _LogoBadge(),
            ),
          ),
          const SizedBox(height: 24),
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: const _BrandText(),
            ),
          ),
          const Spacer(flex: 3),
          FadeTransition(
            opacity: _fadeAnimation,
            child: _ProgressBar(animation: _progressAnimation),
          ),
          const SizedBox(height: 56),
        ],
      ),
    );
  }
}

/// Dark square badge with white dumbbell icon, slightly tilted — matches Stitch.
class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.05, // slight tilt matching Stitch design
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF1E2535),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.fitness_center_rounded, // dumbbell icon
            color: AppColors.primary,
            size: 34,
          ),
        ),
      ),
    );
  }
}

/// Title in primary blue (#ADC6FF), subtitle in muted onSurfaceVariant.
class _BrandText extends StatelessWidget {
  const _BrandText();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Simply Tracker',
          textAlign: TextAlign.center,
          style: GoogleFonts.lexend(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: -0.01 * 28,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Track your workouts simply.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Animated horizontal linear progress bar in secondary green (#4AE176),
/// matching the Stitch design — track is dark, fill animates left to right.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return SizedBox(
          width: 120,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: animation.value,
              minHeight: 3,
              backgroundColor: AppColors.outlineVariant.withValues(alpha: 0.4),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.secondary,
              ),
            ),
          ),
        );
      },
    );
  }
}
