import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/pixel_button.dart';

/// The app's front door — the first onboarding screen, before the cold open.
/// A calm, confident landing: brand mark + promise + a single working CTA
/// ([onGetStarted]) into the intro. SIGN IN is intentionally inert for now
/// (beta — no account system); it stays pressable for feel but does nothing.
class WelcomeLandingView extends StatefulWidget {
  const WelcomeLandingView({super.key, required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  State<WelcomeLandingView> createState() => _WelcomeLandingViewState();
}

class _WelcomeLandingViewState extends State<WelcomeLandingView>
    with TickerProviderStateMixin {
  // Gentle idle loop for the hero logo — a slight float + glow-breathe. Goes
  // static under reduced motion (mirrors AmbientDrift / PowerOn).
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  // One-shot departure on GET STARTED: the logo punches forward + the screen
  // blooms white while the chrome clears, handing off to the flow's "boot the
  // cabinet" CRT power-cycle. Skipped under reduced motion.
  late final AnimationController _depart = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );
  bool _departing = false;

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion) {
      _idle.stop();
      _idle.value = 0;
    } else if (!_idle.isAnimating && !_departing) {
      _idle.repeat();
    }
  }

  /// GET STARTED: play the departure (logo zoom + white bloom), then hand off to
  /// the flow. Reduced motion skips straight to the hand-off.
  void _onGetStarted() {
    if (_departing) return;
    if (_reduceMotion) {
      widget.onGetStarted();
      return;
    }
    setState(() => _departing = true);
    _idle.stop();
    _depart.forward(from: 0).whenComplete(() {
      if (mounted) widget.onGetStarted();
    });
  }

  @override
  void dispose() {
    _idle.dispose();
    _depart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_idle, _depart]),
      builder: (context, _) {
        final d = _depart.value;
        final departing = d > 0;
        // Chrome (wordmark, tagline, CTAs, beta) clears early; the logo punches
        // forward; a white bloom floods late so the hand-off to the flow's boot
        // overlay (which opens on a white hold) is seamless.
        final chromeFade = Curves.easeOut.transform(
          (d / 0.55).clamp(0.0, 1.0).toDouble(),
        );
        final chromeOpacity = (1 - chromeFade).clamp(0.0, 1.0).toDouble();
        final chromeDrift = chromeFade * 16;
        final logoScale = 1 + 1.7 * Curves.easeInCubic.transform(d); // → ~2.7
        final veil = (Curves.easeIn.transform(d) * 0.9)
            .clamp(0.0, 1.0)
            .toDouble();
        final phase = math.sin(_idle.value * 2 * math.pi);

        Widget chrome(Widget child) => Opacity(
          opacity: chromeOpacity,
          child: Transform.translate(
            offset: Offset(0, chromeDrift),
            child: child,
          ),
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _WelcomeBackdrop()),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Spacer(flex: 5),
                    Transform.translate(
                      offset: (_reduceMotion || departing)
                          ? Offset.zero
                          : Offset(0, phase * 5), // ~±5px idle float
                      child: Transform.scale(
                        scale: _reduceMotion
                            ? 1
                            : departing
                            ? logoScale // punch forward on departure
                            : 1 +
                                  0.025 *
                                      (0.5 + 0.5 * phase), // idle glow breathe
                        child: Image.asset(
                          'assets/branding/app_logo.png',
                          key: const ValueKey('welcome_app_logo'),
                          width: 168,
                          height: 168,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                    const SizedBox(height: kSpace4),
                    chrome(
                      const Text(
                        'IRONBIT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 24,
                          color: kNeon,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: kSpace3),
                    chrome(
                      Text(
                        'Every rep builds your character.',
                        textAlign: TextAlign.center,
                        style: AppFonts.shareTechMono(
                          color: kMutedText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Spacer(flex: 6),
                    chrome(
                      PixelButton(
                        label: 'GET STARTED',
                        onPressed: _onGetStarted,
                      ),
                    ),
                    const SizedBox(height: kSpace2),
                    // Inert for now (beta — no accounts). Stays pressable for feel.
                    chrome(
                      PixelButton(
                        label: 'SIGN IN',
                        secondary: true,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(height: kSpace3),
                    chrome(
                      Text(
                        'Still in beta version, no accounts management yet.',
                        textAlign: TextAlign.center,
                        style: AppFonts.shareTechMono(
                          color: kMutedText,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: kSpace3),
                  ],
                ),
              ),
            ),
            if (veil > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: veil,
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Subtle CRT texture: quiet scanlines + a faint neon horizon line that fills
/// the space between the wordmark and the CTAs (a restrained nod to the arcade
/// horizon, without a busy full grid).
class _WelcomeBackdrop extends CustomPainter {
  const _WelcomeBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final scan = Paint()
      ..color = const Color(0x08FFFFFF)
      ..strokeWidth = 1
      ..isAntiAlias = false;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y + 2), Offset(size.width, y + 2), scan);
    }

    final hy = size.height * 0.6;
    canvas.drawLine(
      Offset(0, hy),
      Offset(size.width, hy),
      Paint()
        ..color = kNeon.withValues(alpha: 0.10)
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawLine(
      Offset(0, hy),
      Offset(size.width, hy),
      Paint()
        ..color = kNeon.withValues(alpha: 0.14)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _WelcomeBackdrop oldDelegate) => false;
}
