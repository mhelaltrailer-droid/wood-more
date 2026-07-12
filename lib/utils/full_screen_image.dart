import 'package:flutter/material.dart';

/// فتح صورة مرفق بملء الشاشة مع تكبير/تصغير.
void showFullScreenImage(BuildContext context, String imagePath) {
  final path = imagePath.trim();
  if (path.isEmpty) return;
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.black87,
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: MediaQuery.sizeOf(ctx).height * 0.8,
            child: InteractiveViewer(
              child: Center(
                child: Image.network(
                  path,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'تعذر عرض الصورة',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        ],
      ),
    ),
  );
}
