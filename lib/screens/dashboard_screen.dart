import 'package:flutter/material.dart';

enum DashboardHealthStatus { stable, warning, critical }

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const List<_ProjectStatusItem> _projectStatuses = [
    _ProjectStatusItem(
      name: 'North Tower',
      workers: 34,
      isReportSubmitted: true,
    ),
    _ProjectStatusItem(
      name: 'Central Plaza',
      workers: 21,
      isReportSubmitted: false,
    ),
    _ProjectStatusItem(
      name: 'West Warehouse',
      workers: 17,
      isReportSubmitted: true,
    ),
    _ProjectStatusItem(
      name: 'East Villas',
      workers: 29,
      isReportSubmitted: false,
    ),
  ];

  static const List<_AlertItem> _alerts = [
    _AlertItem(
      title: 'Project without report',
      description: 'Central Plaza has not submitted today\'s report.',
      icon: Icons.warning_amber_rounded,
      color: Colors.orange,
    ),
    _AlertItem(
      title: 'High expenses warning',
      description: 'Today\'s expenses exceeded the daily expected budget.',
      icon: Icons.attach_money_rounded,
      color: Colors.deepOrange,
    ),
    _AlertItem(
      title: 'Damage report exists',
      description: 'A damage issue was reported in East Villas site.',
      icon: Icons.info_outline_rounded,
      color: Colors.blue,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    const int activeProjectsToday = 4;
    const int totalWorkersToday = 101;
    const double totalExpensesToday = 32450.00;
    const int totalIssuesToday = 3;

    final missingReports = _projectStatuses
        .where((project) => !project.isReportSubmitted)
        .toList(growable: false);
    final status = _buildStatus(
      issuesCount: totalIssuesToday,
      missingReportsCount: missingReports.length,
      totalExpenses: totalExpensesToday,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Management Dashboard'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: [
              _SummaryCard(
                title: 'Active Projects',
                value: '$activeProjectsToday',
                icon: Icons.apartment_rounded,
                backgroundColor: Colors.blue.shade50,
              ),
              _SummaryCard(
                title: 'Total Workers',
                value: '$totalWorkersToday',
                icon: Icons.groups_rounded,
                backgroundColor: Colors.green.shade50,
              ),
              _SummaryCard(
                title: 'Total Expenses',
                value: '\$${totalExpensesToday.toStringAsFixed(0)}',
                icon: Icons.payments_rounded,
                backgroundColor: Colors.purple.shade50,
              ),
              _SummaryCard(
                title: 'Issues / Damages',
                value: '$totalIssuesToday',
                icon: Icons.report_problem_rounded,
                backgroundColor: Colors.orange.shade50,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DailyStatusCard(status: status),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Alerts',
            child: Column(
              children: _alerts
                  .map(
                    (alert) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AlertTile(alert: alert),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Projects Status',
            child: Column(
              children: _projectStatuses
                  .map(
                    (project) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ProjectStatusTile(project: project),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Missing Reports (Today)',
            headerColor: Colors.red.shade800,
            child: missingReports.isEmpty
                ? const _EmptyStateText(
                    text: 'All projects submitted today\'s report.',
                  )
                : Column(
                    children: missingReports
                        .map(
                          (project) => Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.cancel_rounded,
                                  color: Colors.red.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    project.name,
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  DashboardHealthStatus _buildStatus({
    required int issuesCount,
    required int missingReportsCount,
    required double totalExpenses,
  }) {
    if (issuesCount >= 5 || missingReportsCount >= 3 || totalExpenses > 50000) {
      return DashboardHealthStatus.critical;
    }
    if (issuesCount >= 2 || missingReportsCount >= 1 || totalExpenses > 30000) {
      return DashboardHealthStatus.warning;
    }
    return DashboardHealthStatus.stable;
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color backgroundColor;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyStatusCard extends StatelessWidget {
  final DashboardHealthStatus status;

  const _DailyStatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      DashboardHealthStatus.stable => (
          'Stable',
          Colors.green,
          Icons.check_circle_rounded,
        ),
      DashboardHealthStatus.warning => (
          'Warning',
          Colors.amber.shade800,
          Icons.warning_amber_rounded,
        ),
      DashboardHealthStatus.critical => (
          'Critical',
          Colors.red,
          Icons.error_rounded,
        ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Today\'s Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Color? headerColor;

  const _SectionCard({
    required this.title,
    required this.child,
    this.headerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: headerColor,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final _AlertItem alert;

  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(alert.icon, color: alert.color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.description,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectStatusTile extends StatelessWidget {
  final _ProjectStatusItem project;

  const _ProjectStatusTile({required this.project});

  @override
  Widget build(BuildContext context) {
    final statusColor = project.isReportSubmitted ? Colors.green : Colors.red;
    final statusLabel = project.isReportSubmitted ? 'Submitted' : 'Missing';
    final statusIcon = project.isReportSubmitted ? '✔' : '❌';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text('Workers: ${project.workers}'),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$statusIcon $statusLabel',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateText extends StatelessWidget {
  final String text;

  const _EmptyStateText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: TextStyle(color: Colors.grey.shade700),
      ),
    );
  }
}

class _AlertItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _AlertItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _ProjectStatusItem {
  final String name;
  final int workers;
  final bool isReportSubmitted;

  const _ProjectStatusItem({
    required this.name,
    required this.workers,
    required this.isReportSubmitted,
  });
}
