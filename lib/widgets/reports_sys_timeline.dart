import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reports_sys_model.dart';

class ReportsSysTimeline extends StatelessWidget {
  final List<ReportsSysActionModel> actions;

  const ReportsSysTimeline({super.key, required this.actions});

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
              'مسار التقرير',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...actions.map((a) {
              final toLabel = a.toUserName != null && a.toUserName!.isNotEmpty
                  ? ' → ${a.toUserName}'
                  : '';
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
                            '${a.actorUserName}: ${a.actionLabelAr}$toLabel',
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

class ReportsSysReviewersChip extends StatelessWidget {
  final List<ReportsSysReviewerModel> reviewers;

  const ReportsSysReviewersChip({super.key, required this.reviewers});

  @override
  Widget build(BuildContext context) {
    if (reviewers.isEmpty) return const SizedBox.shrink();
    return Card(
      color: const Color(0xFFF1F8E9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المطلعون على التقرير',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: reviewers
                  .map(
                    (r) => Chip(
                      avatar: const Icon(Icons.person_outline, size: 18),
                      label: Text(r.userName),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
