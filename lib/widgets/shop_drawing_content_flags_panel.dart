import 'package:flutter/material.dart';

/// خانات SD / QS / Dashboard — تحديد محتوى المرفقات أو عرضها للقراءة فقط.
class ShopDrawingContentFlagsPanel extends StatelessWidget {
  final bool contentSd;
  final bool contentQs;
  final bool contentDashboard;
  final bool readOnly;
  final ValueChanged<bool>? onSdChanged;
  final ValueChanged<bool>? onQsChanged;
  final ValueChanged<bool>? onDashboardChanged;

  const ShopDrawingContentFlagsPanel({
    super.key,
    required this.contentSd,
    required this.contentQs,
    required this.contentDashboard,
    this.readOnly = false,
    this.onSdChanged,
    this.onQsChanged,
    this.onDashboardChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          readOnly ? 'المحتوى المرفق' : 'حدد المحتوى المرفق (اختياري)',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            _flagTile(
              label: 'SD',
              value: contentSd,
              onChanged: readOnly ? null : onSdChanged,
            ),
            _flagTile(
              label: 'QS',
              value: contentQs,
              onChanged: readOnly ? null : onQsChanged,
            ),
            _flagTile(
              label: 'Dashboard',
              value: contentDashboard,
              onChanged: readOnly ? null : onDashboardChanged,
            ),
          ],
        ),
      ],
    );
  }

  Widget _flagTile({
    required String label,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    final chip = _buildChipShell(
      selected: value,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            value ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
            color: value ? const Color(0xFF1B5E20) : Colors.grey.shade500,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: value ? const Color(0xFF1B5E20) : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );

    if (onChanged == null) return chip;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(24),
        child: chip,
      ),
    );
  }

  Widget _buildChipShell({
    required bool selected,
    required Widget child,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE8F5E9) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selected ? const Color(0xFF2E7D32) : Colors.grey.shade400,
          width: selected ? 2 : 1,
        ),
      ),
      child: child,
    );
  }
}
