import 'dart:math';

import 'package:flutter/material.dart';

class AnimatedLogoSplashScreen extends StatefulWidget {
  final Widget child;

  const AnimatedLogoSplashScreen({super.key, required this.child});

  @override
  State<AnimatedLogoSplashScreen> createState() =>
      _AnimatedLogoSplashScreenState();
}

class _AnimatedLogoSplashScreenState extends State<AnimatedLogoSplashScreen>
    with SingleTickerProviderStateMixin {
  static const int _rows = 6;
  static const int _cols = 6;
  late final AnimationController _controller;
  late final List<_PieceSpec> _pieces;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _pieces = List.generate(_rows * _cols, (_) {
      final dx = (rng.nextDouble() - 0.5) * 320;
      final dy = (rng.nextDouble() - 0.5) * 320;
      final angle = (rng.nextDouble() - 0.5) * 1.2;
      final scale = 0.65 + rng.nextDouble() * 0.55;
      final delay = rng.nextDouble() * 0.42;
      return _PieceSpec(
        startOffset: Offset(dx, dy),
        startRotation: angle,
        startScale: scale,
        delay: delay,
      );
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3450),
    )..forward();

    Future.delayed(const Duration(milliseconds: 3900), () {
      if (!mounted) return;
      setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 210,
                height: 210,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: List.generate(_rows * _cols, (index) {
                        final row = index ~/ _cols;
                        final col = index % _cols;
                        final pieceW = 210 / _cols;
                        final pieceH = 210 / _rows;
                        final spec = _pieces[index];
                        final local =
                            ((_controller.value - spec.delay) /
                                    (1 - spec.delay))
                                .clamp(0.0, 1.0);
                        final eased = Curves.easeInOutCubic.transform(local);
                        final tx = spec.startOffset.dx * (1 - eased);
                        final ty = spec.startOffset.dy * (1 - eased);
                        final angle = spec.startRotation * (1 - eased);
                        final scale = 1 + (spec.startScale - 1) * (1 - eased);

                        return Positioned(
                          left: col * pieceW,
                          top: row * pieceH,
                          width: pieceW,
                          height: pieceH,
                          child: Transform.translate(
                            offset: Offset(tx, ty),
                            child: Transform.rotate(
                              angle: angle,
                              child: Transform.scale(
                                scale: scale,
                                child: Opacity(
                                  opacity: eased,
                                  child: ClipRect(
                                    child: Align(
                                      alignment: Alignment(
                                        -1 + (2 * col + 1) / _cols,
                                        -1 + (2 * row + 1) / _rows,
                                      ),
                                      widthFactor: 1 / _cols,
                                      heightFactor: 1 / _rows,
                                      child: Image.asset(
                                        'assets/images/logo.png',
                                        width: 210,
                                        height: 210,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _controller,
                  curve: const Interval(0.52, 1, curve: Curves.easeInOutCubic),
                ),
                child: const Text(
                  'Wood & More Interiors',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PieceSpec {
  final Offset startOffset;
  final double startRotation;
  final double startScale;
  final double delay;

  const _PieceSpec({
    required this.startOffset,
    required this.startRotation,
    required this.startScale,
    required this.delay,
  });
}
