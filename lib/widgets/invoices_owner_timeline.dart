import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/invoices_owner_model.dart';

class InvoicesOwnerTimeline extends StatelessWidget {
  final List<InvoicesOwnerActionModel> actions;

  const InvoicesOwnerTimeline({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const Text('لا يوجد مسار بعد');
    }
    final fmt = DateFormat('dd/MM/yyyy HH:mm', 'ar');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'مسار الطلب',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...actions.map((a) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 10,
                      color: Color(0xFF1B5E20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${a.actorUserName}: ${a.actionLabelAr}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (a.comment != null && a.comment!.trim().isNotEmpty)
                            Text(
                              a.comment!,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          Text(
                            fmt.format(a.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
