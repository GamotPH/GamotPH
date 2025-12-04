// lib/screens/logs/reportLogs_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/providers.dart';

class ReportLogsPage extends ConsumerWidget {
  const ReportLogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep this listened to so realtime invalidations work
    ref.watch(metricsRealtimeProvider);

    final logsAsync = ref.watch(reportLogsProvider);
    final df = DateFormat('MMM d, yyyy • h:mm a');

    return Container(
      color: const Color(0xFFF9F6FF), // soft app background
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (e, _) =>
                      Center(child: Text('Failed to load report logs: $e')),
              data: (logs) {
                if (logs.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Header(),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Center(
                          child: Text(
                            'No ADR reports yet for the selected range.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.black54),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(count: logs.length),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: logs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = logs[index];
                          return _ReportLogCard(item: item, df: df);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/* ───────────────────────── Severity helpers ─────────────────────────── */

Color _severityBgColor(String sev) {
  final s = sev.toLowerCase();
  if (s.contains('severe') || s.contains('life')) {
    return Colors.red.shade100;
  }
  if (s.contains('moderate')) {
    return Colors.orange.shade100;
  }
  if (s.contains('mild')) {
    return Colors.green.shade100;
  }
  return Colors.grey.shade100;
}

Color _severityTextColor(String sev) {
  final s = sev.toLowerCase();
  if (s.contains('severe') || s.contains('life')) {
    return Colors.red.shade800;
  }
  if (s.contains('moderate')) {
    return Colors.orange.shade800;
  }
  if (s.contains('mild')) {
    return Colors.green.shade800;
  }
  return Colors.grey.shade800;
}

/* ───────────────────────── Header ─────────────────────────── */

class _Header extends StatelessWidget {
  final int? count;
  const _Header({this.count});

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 640;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (count != null)
          Text(
            '$count reports shown (live updates)',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
      ],
    );
  }
}

/* ───────────────────────── List card ─────────────────────────── */

class _ReportLogCard extends StatelessWidget {
  final ReportLogItem item;
  final DateFormat df;

  const _ReportLogCard({required this.item, required this.df});

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 640;

    final dateText = df.format(item.createdAt);
    final severity = item.severity.isNotEmpty ? item.severity : 'Unspecified';

    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => _ReportDetailDialog(item: item, df: df),
          );
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isPhone ? 12 : 16,
            vertical: isPhone ? 10 : 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Leading icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.assignment,
                  size: 18,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(width: 12),
              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: medicine + severity chip
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.displayMedicine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _severityBgColor(severity),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            severity,
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(
                              color: _severityTextColor(severity),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Report ID + date
                    Text(
                      'Report #${item.id} • $dateText',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 2),
                    // Location
                    Text(
                      item.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                    ),
                    if (item.reactionDescription.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.reactionDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: isPhone ? 12 : 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ───────────────────────── Detail dialog ─────────────────────────── */

class _ReportDetailDialog extends StatelessWidget {
  final ReportLogItem item;
  final DateFormat df;

  const _ReportDetailDialog({required this.item, required this.df});

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 640;
    final severity = item.severity.isNotEmpty ? item.severity : 'Unspecified';
    final dateText = df.format(item.createdAt);

    final gender =
        item.patientGender.isNotEmpty ? item.patientGender : 'Not specified';
    final age = item.patientAge.isNotEmpty ? item.patientAge : 'Not specified';
    final weight =
        item.patientWeight.isNotEmpty ? item.patientWeight : 'Not specified';
    final foodIntake =
        item.foodIntake.isNotEmpty ? item.foodIntake : 'Not specified';
    final reason =
        item.reasonForTaking.isNotEmpty
            ? item.reasonForTaking
            : 'Not specified';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isPhone ? 16 : 24,
            vertical: isPhone ? 16 : 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.assignment,
                        size: 20,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.displayMedicine,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Report #${item.id}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _severityBgColor(severity),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        severity,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _severityTextColor(severity),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),

                const SizedBox(height: 12),
                Text(
                  'Report information',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _detailRow(context, label: 'Date submitted', value: dateText),
                const SizedBox(height: 6),
                _detailRow(context, label: 'Location', value: item.location),
                if (item.medicineGeneric.isNotEmpty ||
                    item.medicineBrand.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _detailRow(
                    context,
                    label: 'Medicine (generic)',
                    value:
                        item.medicineGeneric.isNotEmpty
                            ? item.medicineGeneric
                            : '—',
                  ),
                  const SizedBox(height: 6),
                  _detailRow(
                    context,
                    label: 'Medicine (brand)',
                    value:
                        item.medicineBrand.isNotEmpty
                            ? item.medicineBrand
                            : '—',
                  ),
                ],

                const SizedBox(height: 16),
                Text(
                  'Patient details',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _detailRow(context, label: 'Gender', value: gender),
                const SizedBox(height: 6),
                _detailRow(context, label: 'Age', value: age),
                const SizedBox(height: 6),
                _detailRow(context, label: 'Weight', value: weight),
                const SizedBox(height: 6),
                _detailRow(context, label: 'Food intake', value: foodIntake),
                const SizedBox(height: 6),
                _detailRow(context, label: 'Reason for taking', value: reason),

                const SizedBox(height: 16),
                Text(
                  'Reaction description',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  item.reactionDescription.isNotEmpty
                      ? item.reactionDescription
                      : 'No reaction description provided.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

                const SizedBox(height: 16),
                Text(
                  'Uploaded image',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (item.drugImageUrl != null && item.drugImageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.network(
                        item.drugImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Text('Failed to load image'),
                            ),
                      ),
                    ),
                  )
                else
                  Text(
                    'None',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                  ),

                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final styleLabel = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Colors.black54);
    final styleValue = Theme.of(context).textTheme.bodyMedium;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 140, child: Text(label, style: styleLabel)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: styleValue)),
      ],
    );
  }
}
