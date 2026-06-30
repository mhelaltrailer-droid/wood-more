import 'package:flutter/material.dart';

import '../core/shop_drawing_constants.dart';
import '../models/user_model.dart';
import 'shop_drawing_hub_screen.dart';

/// بوابة اختيار نوع المستند: Shop-Drawing أو PO.
class ShopDrawingTypeGateScreen extends StatelessWidget {
  final UserModel currentUser;

  const ShopDrawingTypeGateScreen({
    super.key,
    required this.currentUser,
  });

  void _openHub(BuildContext context, String documentType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShopDrawingHubScreen(
          currentUser: currentUser,
          documentType: documentType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(shopDrawingHomeIconLabel),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'اختر نوع المستند',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1B5E20),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _TypeButton(
                  label: 'Shop-Drawing',
                  icon: Icons.architecture_outlined,
                  onPressed: () => _openHub(
                    context,
                    shopDrawingDocumentTypeShopDrawing,
                  ),
                ),
                const SizedBox(height: 20),
                _TypeButton(
                  label: 'PO',
                  icon: Icons.receipt_long_outlined,
                  onPressed: () => _openHub(
                    context,
                    shopDrawingDocumentTypePo,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 72,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: Icon(icon, size: 28),
        label: Text(label),
      ),
    );
  }
}
