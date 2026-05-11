import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../screens/operation_reports_tracking_screen.dart';
import '../services/route_restore.dart';

class AnimatedOperationTrackingCard extends StatefulWidget {
  final UserModel user;

  const AnimatedOperationTrackingCard({super.key, required this.user});

  @override
  State<AnimatedOperationTrackingCard> createState() =>
      _AnimatedOperationTrackingCardState();
}

class _AnimatedOperationTrackingCardState
    extends State<AnimatedOperationTrackingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final glowOpacity = 0.18 + (0.14 * t);
        final scale = 1.0 + (0.018 * t);
        final dy = -2.0 * t;

        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(
            scale: scale,
            child: InkWell(
              onTap: () async {
                await pushAndSaveRoute(
                  context,
                  'operation-reports-tracking',
                  OperationReportsTrackingScreen(currentUser: widget.user),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF00695C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1B5E20).withOpacity(glowOpacity),
                      blurRadius: 14 + (8 * t),
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.fact_check,
                      size: 64,
                      color: Colors.white.withOpacity(0.95),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'متابعة تقارير التشغيل',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'متابعة كل أنواع التقارير وحالة كل تقرير في دورة المراجعة',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.92),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
