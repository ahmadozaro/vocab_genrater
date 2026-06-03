import 'dart:math';

import 'package:ai/core/theme/colors.dart';
import 'package:flutter/material.dart';

class AppMotion {
  static const fast = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);
  static const curve = Curves.easeOutCubic;
  static const bounce = Curves.easeOutBack;

  static PageRouteBuilder<T> sharedRoute<T>(
    Widget page, {
    RouteSettings? settings,
    Offset beginOffset = const Offset(0.06, 0),
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: normal,
      reverseTransitionDuration: fast,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: curve);
        final exit = CurvedAnimation(parent: secondaryAnimation, curve: curve);
        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(curved),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: beginOffset,
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
              child: FadeTransition(
                opacity: Tween<double>(begin: 1, end: 0.92).animate(exit),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class LearningPageTransitionsBuilder extends PageTransitionsBuilder {
  const LearningPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: AppMotion.curve);
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(curved),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.035, 0.015),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final double pressedScale;
  final bool enabled;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.pressedScale = 0.97,
    this.enabled = true,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(12);
    return AnimatedScale(
      scale: _pressed ? widget.pressedScale : 1,
      duration: AppMotion.fast,
      curve: _pressed ? Curves.easeOut : AppMotion.bounce,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: widget.enabled ? widget.onTap : null,
          onHighlightChanged: _setPressed,
          onHover: (hovering) {
            if (!hovering) _setPressed(false);
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class AnimatedEntry extends StatelessWidget {
  final Widget child;
  final int index;
  final Offset beginOffset;

  const AnimatedEntry({
    super.key,
    required this.child,
    this.index = 0,
    this.beginOffset = const Offset(0, 0.06),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + min(index * 45, 240)),
      curve: AppMotion.curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: beginOffset * (1 - value) * 80,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class AnimatedLearningCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final bool highlight;

  const AnimatedLearningCard({
    super.key,
    required this.child,
    this.onTap,
    this.margin,
    this.padding,
    this.color,
    this.borderRadius,
    this.boxShadow,
    this.highlight = false,
  });

  @override
  State<AnimatedLearningCard> createState() => _AnimatedLearningCardState();
}

class _AnimatedLearningCardState extends State<AnimatedLearningCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(14);
    final baseColor = widget.color ?? AppColors.card;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.012 : 1,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.curve,
          margin: widget.margin,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.highlight ? AppColors.primaryLight : baseColor,
            borderRadius: radius,
            border: widget.highlight
                ? Border.all(color: AppColors.primary.withOpacity(0.45))
                : null,
            boxShadow:
                widget.boxShadow ??
                [
                  BoxShadow(
                    color: Colors.black.withOpacity(_hovered ? 0.09 : 0.04),
                    blurRadius: _hovered ? 16 : 8,
                    offset: Offset(0, _hovered ? 7 : 3),
                  ),
                ],
          ),
          child: PressableScale(
            onTap: widget.onTap,
            enabled: widget.onTap != null,
            borderRadius: radius,
            pressedScale: 0.985,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class PulseLoader extends StatefulWidget {
  final double size;

  const PulseLoader({super.key, this.size = 42});

  @override
  State<PulseLoader> createState() => _PulseLoaderState();
}

class _PulseLoaderState extends State<PulseLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.slow)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.88,
        end: 1.08,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.24),
              blurRadius: 18,
            ),
          ],
        ),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedProgressBar extends StatelessWidget {
  final double value;
  final double minHeight;
  final Color? backgroundColor;
  final Color? color;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.minHeight = 8,
    this.backgroundColor,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      builder: (context, animatedValue, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: animatedValue,
            minHeight: minHeight,
            backgroundColor: backgroundColor ?? AppColors.primaryLight,
            color: color ?? AppColors.primary,
          ),
        );
      },
    );
  }
}

class CelebrationBurst extends StatefulWidget {
  final bool active;
  final double height;

  const CelebrationBurst({super.key, required this.active, this.height = 160});

  @override
  State<CelebrationBurst> createState() => _CelebrationBurstState();
}

class _CelebrationBurstState extends State<CelebrationBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiPiece> _pieces;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.slow);
    _pieces = _createPieces();
    if (widget.active) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant CelebrationBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_ConfettiPiece> _createPieces() {
    final random = Random(7);
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      AppColors.warning,
      Colors.white,
    ];
    return List.generate(34, (index) {
      return _ConfettiPiece(
        x: random.nextDouble(),
        delay: random.nextDouble() * 0.22,
        drift: (random.nextDouble() - 0.5) * 110,
        size: 4 + random.nextDouble() * 7,
        color: colors[index % colors.length],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _ConfettiPainter(_controller.value, _pieces),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _ConfettiPiece {
  final double x;
  final double delay;
  final double drift;
  final double size;
  final Color color;

  const _ConfettiPiece({
    required this.x,
    required this.delay,
    required this.drift,
    required this.size,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiPiece> pieces;

  const _ConfettiPainter(this.progress, this.pieces);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final piece in pieces) {
      final local = ((progress - piece.delay) / (1 - piece.delay)).clamp(
        0.0,
        1.0,
      );
      if (local <= 0) continue;
      final eased = Curves.easeOutCubic.transform(local);
      paint.color = piece.color.withOpacity((1 - local).clamp(0.0, 1.0));
      final x = piece.x * size.width + piece.drift * eased;
      final y = size.height * 0.15 + size.height * 0.72 * eased;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(eased * pi * 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: piece.size,
            height: piece.size * 1.8,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
