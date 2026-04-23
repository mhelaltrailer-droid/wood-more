import 'package:flutter/material.dart';

import '../models/user_model.dart';

class SiteEngineerReportsScreen extends StatelessWidget {
  final UserModel user;

  const SiteEngineerReportsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التقارير'),
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'تم تعطيل هذه الشاشة مؤقتًا بعد التراجع عن التعديلات الأخيرة.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
