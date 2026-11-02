import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../target_list/views/target_list_view.dart';

class SplashScreenView extends StatefulWidget {
  const SplashScreenView({super.key});

  @override
  State<SplashScreenView> createState() => _SplashScreenViewState();
}

class _SplashScreenViewState extends State<SplashScreenView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Animations breakdown across a 2.8s sequence
  late final Animation<double> _pigScaleAnim;
  late final Animation<double> _pigFadeAnim;
  late final Animation<double> _coinDropAnim;
  late final Animation<double> _coinSpinAnim;
  late final Animation<double> _coinOpacityAnim;
  late final Animation<double> _pigSquashXAnim;
  late final Animation<double> _pigSquashYAnim;
  late final Animation<double> _pigWobbleAnim;
  late final Animation<double> _burstProgressAnim;
  late final Animation<double> _textFadeAnim;
  late final Animation<Offset> _textSlideAnim;
  late final Animation<double> _taglineFadeAnim;
  late final Animation<double> _progressAnim;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    // 1. Pig Entrance (0.00 -> 0.35)
    _pigScaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.2, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 75,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.00, 0.35),
      ),
    );

    _pigFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.00, 0.25, curve: Curves.easeOut),
      ),
    );

    // 2. Coin Drop into Slot (0.30 -> 0.52)
    _coinDropAnim = Tween<double>(begin: -150.0, end: -20.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.52, curve: Curves.easeInQuad),
      ),
    );

    _coinSpinAnim = Tween<double>(begin: 0.0, end: math.pi * 4).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.52, curve: Curves.linear),
      ),
    );

    _coinOpacityAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.53),
      ),
    );

    // 3. Pig Delight Squash & Wobble (0.52 -> 0.72)
    _pigSquashXAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.14)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.14, end: 0.94)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.94, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.52, 0.72),
      ),
    );

    _pigSquashYAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.88)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.88, end: 1.06)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.52, 0.72),
      ),
    );

    _pigWobbleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.08, end: 0.07)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.07, end: -0.04)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.04, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.52, 0.72),
      ),
    );

    // 4. Particle Burst & Ripple (0.52 -> 0.75)
    _burstProgressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.52, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    // 5. Typography Reveal (0.56 -> 0.82)
    _textFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.56, 0.78, curve: Curves.easeOut),
      ),
    );

    _textSlideAnim = Tween<Offset>(
      begin: const Offset(0.0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.56, 0.78, curve: Curves.easeOutCubic),
      ),
    );

    _taglineFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.66, 0.86, curve: Curves.easeOut),
      ),
    );

    // 6. Loading Progress (0.60 -> 0.95)
    _progressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.60, 0.95, curve: Curves.easeInOutCubic),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToHome();
      }
    });

    _controller.forward();
  }

  void _navigateToHome() {
    if (_navigated || !mounted) return;
    _navigated = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const TargetListView(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _navigateToHome, // Tap anywhere to skip smoothly
      child: Scaffold(
        backgroundColor: const Color(0xFF0F111A),
        body: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Ambient Background Gradient & Faint Glow
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.0, -0.15),
                    radius: 1.1,
                    colors: [
                      Color(0xFF262C44), // Faint top glow
                      Color(0xFF141724), // Mid navy
                      Color(0xFF0A0C13), // Deep outer background
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // 2. Faint Particle Grid / Star Halo behind Mascot
            Positioned(
              top: MediaQuery.of(context).size.height * 0.22,
              child: AnimatedBuilder(
                animation: _burstProgressAnim,
                builder: (context, _) {
                  final progress = _burstProgressAnim.value;
                  return CustomPaint(
                    size: const Size(280, 280),
                    painter: _CoinBurstPainter(progress: progress),
                  );
                },
              ),
            ),

            // 3. Central Mascot & Coin Interactive Stack
            Positioned(
              top: MediaQuery.of(context).size.height * 0.28,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Interactive Mascot Container with Coin
                      SizedBox(
                        width: 200,
                        height: 180,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            // Ground Soft Oval Shadow
                            Positioned(
                              bottom: -8,
                              child: Opacity(
                                opacity: _pigFadeAnim.value * 0.45,
                                child: Container(
                                  width: 140 * _pigSquashXAnim.value,
                                  height: 14 * _pigSquashYAnim.value,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(100),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.7),
                                        blurRadius: 18,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Falling Animated Golden Coin
                            Positioned(
                              top: _coinDropAnim.value,
                              child: Opacity(
                                opacity: _coinOpacityAnim.value,
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.002)
                                    ..rotateY(_coinSpinAnim.value),
                                  child: const _GoldenCoinWidget(),
                                ),
                              ),
                            ),

                            // The Piggy Mascot (With squash, stretch & wobble)
                            Transform.scale(
                              scale: _pigScaleAnim.value,
                              child: Transform.scale(
                                scaleX: _pigSquashXAnim.value,
                                scaleY: _pigSquashYAnim.value,
                                child: Transform.rotate(
                                  angle: _pigWobbleAnim.value,
                                  child: Opacity(
                                    opacity: _pigFadeAnim.value,
                                    child: Container(
                                      width: 156,
                                      height: 156,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF7C8BFF)
                                                .withValues(alpha: 0.22 * _pigFadeAnim.value),
                                            blurRadius: 36,
                                            spreadRadius: 8,
                                          ),
                                          if (_burstProgressAnim.value > 0.0 &&
                                              _burstProgressAnim.value < 0.8)
                                            BoxShadow(
                                              color: const Color(0xFF10B981)
                                                  .withValues(
                                                      alpha: 0.35 *
                                                          (1.0 -
                                                              _burstProgressAnim
                                                                  .value)),
                                              blurRadius: 40,
                                              spreadRadius: 16,
                                            ),
                                        ],
                                      ),
                                      child: Image.asset(
                                        'assets/images/pig_silhouette.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Brand Name: JAGA CUAN (Dribbble clean typography style)
                      SlideTransition(
                        position: _textSlideAnim,
                        child: FadeTransition(
                          opacity: _textFadeAnim,
                          child: Column(
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFFFFFFF),
                                    Color(0xFFE2E8F0),
                                    Color(0xFFCBD5E1),
                                  ],
                                ).createShader(bounds),
                                child: Text(
                                  'JAGA CUAN',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 27,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 3.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              FadeTransition(
                                opacity: _taglineFadeAnim,
                                child: Text(
                                  'Nabung Cerdas & Wujudkan Impian',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF94A3B8),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // 4. Bottom Modern Progress Pill & Footer
            Positioned(
              bottom: 48,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Opacity(
                    opacity: _taglineFadeAnim.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Sleek Minimalist Progress Pill Bar
                        Container(
                          width: 140,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 140 * _progressAnim.value,
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF7C8BFF),
                                  Color(0xFF10B981),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _progressAnim.value > 0.85
                              ? 'Siap menabung!'
                              : 'Menyiapkan celengan...',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A shiny 3D-styled golden coin with specular bevel & sparkle icon
class _GoldenCoinWidget extends StatelessWidget {
  const _GoldenCoinWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.3),
          radius: 0.9,
          colors: [
            Color(0xFFFFF7B2), // Highlight reflection
            Color(0xFFFFC727), // Gold face
            Color(0xFFD97706), // Deep gold
            Color(0xFF92400E), // Gold shadow edge
          ],
          stops: [0.0, 0.45, 0.85, 1.0],
        ),
        border: Border.all(
          color: const Color(0xFFFFFBEB),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.65),
            blurRadius: 14,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFFCD34D).withValues(alpha: 0.8),
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            'Rp',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF78350F),
              shadows: const [
                Shadow(
                  color: Color(0xFFFEF3C7),
                  offset: Offset(0.5, 0.5),
                  blurRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the coin burst sparkle effect & ripple ring
class _CoinBurstPainter extends CustomPainter {
  final double progress; // 0.0 -> 1.0

  _CoinBurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height * 0.46);
    final paint = Paint()..style = PaintingStyle.stroke;

    // Expanding Shockwave Ring
    final ringRadius = 24.0 + (progress * 76.0);
    final ringOpacity = (1.0 - progress).clamp(0.0, 1.0);
    paint.color = const Color(0xFFF59E0B).withValues(alpha: ringOpacity * 0.45);
    paint.strokeWidth = 2.0 * (1.0 - progress);
    canvas.drawCircle(center, ringRadius, paint);

    // Secondary emerald ring (symbolizing savings growth from the leaf)
    final emeraldRadius = 16.0 + (progress * 62.0);
    paint.color = const Color(0xFF10B981).withValues(alpha: ringOpacity * 0.35);
    paint.strokeWidth = 1.5 * (1.0 - progress);
    canvas.drawCircle(center, emeraldRadius, paint);

    // Sparkle Particle Stars radiating outward
    final particlePaint = Paint()..style = PaintingStyle.fill;
    const particleCount = 8;
    for (int i = 0; i < particleCount; i++) {
      final angle = (i * (math.pi * 2 / particleCount)) + (progress * 0.3);
      final distance = 30.0 + (progress * 65.0);
      final px = center.dx + (math.cos(angle) * distance);
      final py = center.dy + (math.sin(angle) * distance * 0.7); // oval dispersion

      final pColor = (i % 2 == 0)
          ? const Color(0xFFFBBF24) // Gold
          : const Color(0xFF34D399); // Emerald leaf sparkle

      particlePaint.color = pColor.withValues(alpha: ringOpacity * 0.85);
      final pRadius = (3.0 * (1.0 - progress)).clamp(0.5, 3.0);
      canvas.drawCircle(Offset(px, py), pRadius, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CoinBurstPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
