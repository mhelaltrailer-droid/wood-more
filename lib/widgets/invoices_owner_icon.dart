import 'package:flutter/material.dart';

/// أيقونة Invoices (Owner) — علامة $ بدون الاعتماد على MaterialIcons
/// (تجنّب اختفاء الأيقونات الجديدة على Flutter Web بسبب كاش الخط).
class InvoicesOwnerIcon extends StatelessWidget {
  final double size;
  final Color color;

  const InvoicesOwnerIcon({
    super.key,
    this.size = 64,
    this.color = const Color(0xFF1B5E20),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          r'$',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: size * 0.78,
            height: 1,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}
