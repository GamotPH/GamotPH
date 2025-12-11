// lib/screens/reports/symptomsActivity.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../data/providers.dart';

class SymptomsActivityPanel extends ConsumerStatefulWidget {
  final String timeframe; // kept for compatibility, but not used now
  final String medicine;
  final double? height;

  const SymptomsActivityPanel({
    super.key,
    required this.timeframe,
    required this.medicine,
    this.height,
  });

  @override
  ConsumerState<SymptomsActivityPanel> createState() =>
      _SymptomsActivityPanelState();
}

class _SymptomsActivityPanelState extends ConsumerState<SymptomsActivityPanel> {
  // Default view: YEARLY
  SymptomsGrouping _grouping = SymptomsGrouping.year;
  int? _selectedYear; // used when grouping == month

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(symptomsProvider);

    return SizedBox(
      height: widget.height,
      child: _Panel(
        title: 'Symptoms Activity',
        trailing: _GroupingButton(
          value: _grouping,
          onChanged: (g) => setState(() => _grouping = g),
        ),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(message: e.toString()),
          data: (raw) {
            // We expect a map: { 'yearly': [...], 'monthly': [...] }
            final yearlyRaw = raw['yearly'];
            final monthlyRaw = raw['monthly'];

            final yearlyBuckets = _normalizeBuckets(yearlyRaw);
            final monthlyBucketsAll = _normalizeBuckets(monthlyRaw);

            if (yearlyBuckets.isEmpty && monthlyBucketsAll.isEmpty) {
              return const Center(
                child: Text('No activity for the selected filters.'),
              );
            }

            // ---- Years list (for dropdown in Monthly view) ----
            // Only keep years that actually have >0 total reports
            final yearsSet = <int>{};

            for (final b in yearlyBuckets) {
              if (b.total > 0) yearsSet.add(b.labelStart.year);
            }
            for (final b in monthlyBucketsAll) {
              if (b.total > 0) yearsSet.add(b.labelStart.year);
            }

            final years = yearsSet.toList()..sort();

            int effectiveYear;
            if (_selectedYear != null && years.contains(_selectedYear)) {
              effectiveYear = _selectedYear!;
            } else if (years.isNotEmpty) {
              effectiveYear = years.last; // latest year with data
            } else {
              // fallback – shouldn't really happen because we filtered by total>0
              effectiveYear = DateTime.now().year;
            }

            // ---- Choose buckets depending on grouping ----
            List<_Bucket> buckets;

            if (_grouping == SymptomsGrouping.year) {
              // One bar per YEAR – but only years that have data
              buckets = yearlyBuckets.where((b) => b.total > 0).toList();
            } else {
              // Monthly view: 12 months of the selected year
              final byMonth = <int, int>{};
              for (final b in monthlyBucketsAll) {
                if (b.labelStart.year == effectiveYear) {
                  byMonth[b.labelStart.month] =
                      (byMonth[b.labelStart.month] ?? 0) + b.total;
                }
              }

              final temp = <_Bucket>[];
              for (var m = 1; m <= 12; m++) {
                final dt = DateTime.utc(effectiveYear, m, 1);
                temp.add(_Bucket(dt, byMonth[m] ?? 0));
              }
              buckets = temp;
            }

            if (buckets.isEmpty) {
              return const Center(
                child: Text('No activity for the selected filters.'),
              );
            }

            final maxVal = buckets
                .map((b) => b.total)
                .reduce((a, b) => a > b ? a : b);
            final ghost = maxVal == 0 ? 1.0 : maxVal.toDouble();
            final leftInterval =
                ((ghost / 4).clamp(1, ghost.toDouble())).toDouble();

            final dfYear = DateFormat('yyyy');
            final dfMonth = DateFormat('MMM');

            final groups = <BarChartGroupData>[
              for (var i = 0; i < buckets.length; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: 4,
                  barRods: [
                    // background bar
                    BarChartRodData(
                      toY: ghost,
                      width: 14,
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    // actual value bar
                    BarChartRodData(
                      toY: buckets[i].total.toDouble(),
                      width: 14,
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                ),
            ];

            final chart = Padding(
              padding: const EdgeInsets.only(
                top: 12,
                right: 8,
                left: 4,
                bottom: 4,
              ),
              child: BarChart(
                BarChartData(
                  maxY: ghost,
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: groups,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor:
                          (group) => Theme.of(context).colorScheme.surface,
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      tooltipMargin: 8,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        if (rodIndex != 1) return null; // skip ghost bar
                        final value = buckets[groupIndex].total;
                        final textStyle =
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ) ??
                            const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            );
                        return BarTooltipItem(value.toString(), textStyle);
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: leftInterval,
                        getTitlesWidget:
                            (v, _) => Text(
                              v.toInt().toString(),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 22,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= buckets.length) {
                            return const SizedBox.shrink();
                          }
                          final d = buckets[i].labelStart;
                          final label =
                              _grouping == SymptomsGrouping.year
                                  ? dfYear.format(d)
                                  : dfMonth.format(d);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              label.toUpperCase(),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );

            // Wrap chart with optional YEAR selector for monthly view
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_grouping == SymptomsGrouping.month && years.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: DropdownButton<int>(
                      value: effectiveYear,
                      underline: const SizedBox.shrink(),
                      onChanged: (y) {
                        if (y == null) return;
                        setState(() => _selectedYear = y);
                      },
                      items:
                          years
                              .map(
                                (y) => DropdownMenuItem<int>(
                                  value: y,
                                  child: Text(y.toString()),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                Expanded(child: chart),
              ],
            );
          },
        ),
      ),
    );
  }
}

/* ======================= Helpers & UI (unchanged) ======================= */

class _Bucket {
  final DateTime labelStart;
  final int total;
  const _Bucket(this.labelStart, this.total);
}

dynamic _getKeyCI(Map m, List<String> names) {
  final lower = <String, dynamic>{
    for (final e in m.entries) e.key.toString().toLowerCase(): e.value,
  };
  for (final n in names) {
    final v = lower[n.toLowerCase()];
    if (v != null) return v;
  }
  return null;
}

int? _monthFromName(String s) {
  final t = s.trim().toLowerCase();
  const names = {
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };
  return names[t];
}

DateTime _coerceDate(dynamic ts, {int? year}) {
  if (ts is DateTime) return ts.toUtc();
  if (ts is String && RegExp(r'^\d{4}-\d{2}$').hasMatch(ts)) {
    final p = ts.split('-');
    return DateTime.utc(int.parse(p[0]), int.parse(p[1]), 1);
  }
  if (ts is String) {
    final m = _monthFromName(ts);
    if (m != null) return DateTime.utc(year ?? DateTime.now().year, m, 1);
    return DateTime.parse(ts).toUtc();
  }
  if (ts is num) {
    final m = ts.toInt().clamp(1, 12);
    return DateTime.utc(year ?? DateTime.now().year, m, 1);
  }
  return DateTime.now().toUtc();
}

int _coerceInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

List<_Bucket> _normalizeBuckets(dynamic raw) {
  final out = <_Bucket>[];

  void eatMap(Map m) {
    final ts = _getKeyCI(m, [
      'labelstart',
      'label_start',
      'bucket',
      'bucketstart',
      'bucket_date',
      'date',
      'period',
      'month',
      'week_start',
      'weekstart',
      'weekStart',
      'x',
      'start',
    ]);
    final yr = _getKeyCI(m, ['year', 'yr']);
    final cnt =
        _getKeyCI(m, [
          'total',
          'count',
          'value',
          'reports',
          'cases',
          'cnt',
          'n',
          'y',
        ]) ??
        0;

    if (ts != null) {
      out.add(
        _Bucket(_coerceDate(ts, year: yr is int ? yr : null), _coerceInt(cnt)),
      );
    }
  }

  if (raw is! Iterable) return out;

  for (final item in raw) {
    if (item is _Bucket) {
      out.add(item);
      continue;
    }

    try {
      final dynamic dateLike =
          (item as dynamic).labelStart ??
          item.date ??
          item.period ??
          item.start ??
          item.weekStart ??
          item.bucket ??
          item.x;
      final int? year = (item as dynamic).year ?? item.yr;
      final dynamic month = (item as dynamic).month;
      final dynamic countLike =
          item.total ??
          item.count ??
          item.value ??
          item.y ??
          item.reports ??
          item.cases ??
          item.cnt ??
          item.n;

      DateTime? dt;
      if (dateLike != null) {
        dt = _coerceDate(dateLike, year: year);
      } else if (month != null) {
        dt = _coerceDate(month, year: year);
      }

      if (dt != null && countLike != null) {
        out.add(_Bucket(dt, _coerceInt(countLike)));
        continue;
      }
    } catch (_) {}

    try {
      final json = (item as dynamic).toJson() as Map<String, dynamic>;
      eatMap(json);
      continue;
    } catch (_) {}

    if (item is Map) {
      eatMap(item);
    }
  }

  out.sort((a, b) => a.labelStart.compareTo(b.labelStart));
  return out;
}

/* ======================= UI bits ======================= */

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Panel({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Failed to load: $message',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Colors.red),
      ),
    );
  }
}

class _GroupingButton extends StatelessWidget {
  final SymptomsGrouping value;
  final ValueChanged<SymptomsGrouping> onChanged;
  const _GroupingButton({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SymptomsGrouping>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder:
          (ctx) => const [
            PopupMenuItem(value: SymptomsGrouping.year, child: Text('Year')),
            PopupMenuItem(value: SymptomsGrouping.month, child: Text('Month')),
          ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value == SymptomsGrouping.year ? 'Year' : 'Month'),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded),
        ],
      ),
    );
  }
}
