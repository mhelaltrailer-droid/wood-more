import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Blocks Projects Dashboard features on mobile — desktop web only.
class ProjectsDashboardDesktopGate extends StatelessWidget {
  final String title;
  final PreferredSizeWidget? appBar;
  final Widget child;

  const ProjectsDashboardDesktopGate({
    super.key,
    required this.title,
    required this.child,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return child;

    return Scaffold(
      appBar: appBar ??
          AppBar(
            title: Text(title),
          ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.computer_outlined,
                size: 72,
                color: Colors.green.shade700,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'استخدم الكمبيوتر للوصول لهذه الميزة',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'افتح التطبيق من المتصفح على جهاز ويندوز:\nwood-more-dtnp.onrender.com',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
