// lib/screens/reports/keyMetrics.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/providers.dart'; // <- where keyMetricsProvider lives

class KeyMetricsPanel extends ConsumerWidget {
  final double height;
  const KeyMetricsPanel({super.key, this.height = 300});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep your realtime subscription so tiles refresh when ADR_Reports changes
    ref.watch(metricsRealtimeProvider);

    final metricsAsync = ref.watch(keyMetricsProvider);
    final topMedAsync = ref.watch(topMedicineProvider);

    final nf = NumberFormat.decimalPattern(); // e.g., 27,009
    final pf = NumberFormat.decimalPercentPattern(
      decimalDigits: 0,
    ); // e.g., 92%

    return _Panel(
      title: 'Key Metrics',
      child: SizedBox(
        height: height,
        child: metricsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(error: e.toString()),
          data: (m) {
            // Repository returns validatedPct in 0–100; NumberFormat expects 0–1
            final activeUsers = nf.format(m.activeUsers);
            final reportedCases = nf.format(m.reportedCases);
            final validatedPctText = pf.format((m.validatedPct) / 100.0);

            return LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final isPhone = w < 640;
                final gap = isPhone ? 8.0 : 10.0;

                // Grid controls: 1 column on narrow, 2 on wider
                int cols(double width) => width < 520 ? 1 : 2;
                double aspect(double width) {
                  if (width >= 900) return 3.6;
                  if (width >= 700) return 3.2;
                  return 2.8;
                }

                return Column(
                  children: [
                    // --- User Stats ---
                    Expanded(
                      child: _SubPanel(
                        title: 'User Stats',
                        child: GridView.count(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          crossAxisCount: cols(w),
                          mainAxisSpacing: gap,
                          crossAxisSpacing: gap,
                          childAspectRatio: aspect(w),
                          children: [
                            _KpiTile(
                              title: 'Active Users',
                              bigValue: activeUsers,
                              trend: null,
                            ),
                            _KpiTile(
                              title: 'Reported Cases',
                              bigValue: reportedCases,
                              trend: null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: gap),

                    // --- Medicine Stats ---
                    Expanded(
                      child: _SubPanel(
                        title: 'Medicine Stats',
                        child: GridView.count(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          crossAxisCount: cols(w),
                          mainAxisSpacing: gap,
                          crossAxisSpacing: gap,
                          childAspectRatio: aspect(w),
                          children: [
                            // Top Medicine tile
                            topMedAsync.when(
                              data: (d) {
                                // d is (String?, int?)
                                final String? nameRaw = d.$1;
                                final int count = d.$2 ?? 0;
                                final String name =
                                    (nameRaw?.trim().isNotEmpty ?? false)
                                        ? nameRaw!.trim()
                                        : '—';
                                return _KpiTile(
                                  title: 'Top Medicine',
                                  bigValue: name,
                                  trend:
                                      count > 0
                                          ? '${nf.format(count)} reports'
                                          : null,
                                );
                              },
                              loading:
                                  () => const _KpiTile(
                                    title: 'Top Medicine',
                                    bigValue: '—',
                                  ),
                              error:
                                  (_, __) => const _KpiTile(
                                    title: 'Top Medicine',
                                    bigValue: '—',
                                  ),
                            ),
                            // Validated Reports tile
                            _KpiTile(
                              title: 'Validated Reports',
                              bigValue: validatedPctText,
                              trend: null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/* ───────────────────────── Helpers / UI scaffolding ────────────────────── */

class _ErrorState extends ConsumerWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Failed to load key metrics:\n$error'),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => ref.invalidate(keyMetricsProvider),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;
  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 640;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isPhone ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: isPhone ? 15.0 : 16.0,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: isPhone ? 10 : 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SubPanel extends StatelessWidget {
  final String title;
  final Widget child;
  const _SubPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 640;
    return Card(
      elevation: 0,
      color: const Color(0xFFF9FAFB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isPhone ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: isPhone ? 12.0 : 13.0,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: isPhone ? 6 : 8),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String title;
  final String bigValue;
  final String? trend;
  const _KpiTile({required this.title, required this.bigValue, this.trend});

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 640;
    final big = TextStyle(
      fontSize: isPhone ? 18.0 : 20.0,
      fontWeight: FontWeight.bold,
    );
    final sub = TextStyle(
      fontSize: isPhone ? 11.0 : 12.0,
      color: Colors.black54,
    );

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: isPhone ? 8 : 10,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Text block
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bigValue,
                    style: big,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ],
              ),
            ),
            if (trend != null && trend!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      trend!.startsWith('-')
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  trend!,
                  style: TextStyle(
                    fontSize: isPhone ? 11.0 : 12.0,
                    color: trend!.startsWith('-') ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
