// lib/screens/reports/clinicalManagement.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/providers.dart';

class ClinicalManagementPanel extends ConsumerWidget {
  // Kept the original class name to avoid breaking imports elsewhere.
  // Internally this now renders the ADR pie via adverseReactionsProvider.
  final double height;
  const ClinicalManagementPanel({super.key, this.height = 280});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(
      adverseReactionsProvider,
    ); // ← switched provider
    final f = ref.watch(filterProvider);
    final fmt = DateFormat('MMM d, yyyy');
    final rangeText = '${fmt.format(f.start)} → ${fmt.format(f.end)}';

    return _Panel(
      title: 'Adverse Drug Reactions', // ← updated title
      subtitle: rangeText,
      child: SizedBox(
        height: height,
        child: dataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Failed to load: $e')),
          data:
              (series) => _ADRDonut(
                labels: series.labels,
                counts: series.values, // raw counts; widget computes %
              ),
        ),
      ),
    );
  }
}

class _ADRDonut extends StatefulWidget {
  final List<String> labels;
  final List<double> counts;
  const _ADRDonut({required this.labels, required this.counts});

  @override
  State<_ADRDonut> createState() => _ADRDonutState();
}

class _ADRDonutState extends State<_ADRDonut> {
  // Stable palette so colors don’t jump after refresh
  final List<Color> _colors = const [
    Color(0xFF4F86F7), // blue
    Color(0xFF7BD6B3), // green
    Color(0xFFF59BB6), // pink
    Color(0xFFF6B358), // yellow/orange
    Color(0xFF8EA2F8), // purple
    Color(0xFF7C8B99), // gray (used if there’s an "Other" slice)
  ];

  int? _touchedIndex;

  double get _total => widget.counts.fold(0.0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    if (widget.counts.isEmpty || _total == 0) {
      return const _EmptyState(message: 'No ADR data for this range.');
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final isPhone = w < 520;
        final isTablet = w >= 520 && w < 840;
        final isDesktop = w >= 840;

        // ↓ Slightly smaller overall footprint
        final double donutSize = isDesktop ? 206.0 : (isTablet ? 190.0 : 160.0);
        final double sectionRadius = donutSize * 0.42;
        final double baseHole = donutSize * 0.34;
        final double titleFont = isPhone ? 10.5 : 12.0;

        // Touch bump: smaller outward bump; some of the emphasis goes inward.
        const double bumpOut = 6.0;
        const double bumpIn = 4.0;

        // Validate the touched index once; reuse everywhere
        final si =
            (_touchedIndex != null &&
                    _touchedIndex! >= 0 &&
                    _touchedIndex! < widget.counts.length)
                ? _touchedIndex!
                : null;

        // Add a little animated padding when anything is touched, to create allowance.
        final bool anyTouched = si != null;
        final EdgeInsets safePad = EdgeInsets.all(anyTouched ? 12 : 4);

        final donut = AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: safePad,
          child: SizedBox(
            width: donutSize,
            height: donutSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MouseRegion(
                  onExit: (_) {
                    if (!mounted) return;
                    setState(() => _touchedIndex = null);
                  },
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: (anyTouched
                              ? baseHole - bumpIn
                              : baseHole)
                          .clamp(18.0, 999.0),
                      startDegreeOffset: -90,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (!mounted) return;

                          // If the event isn't considered interactive, or no section is hit, clear selection.
                          final noHit = response?.touchedSection == null;
                          final notInteractive =
                              !(event.isInterestedForInteractions ?? true);

                          if (noHit || notInteractive) {
                            setState(() => _touchedIndex = null);
                            return;
                          }

                          final idx =
                              response!.touchedSection!.touchedSectionIndex;
                          setState(() {
                            _touchedIndex =
                                (idx >= 0 && idx < widget.counts.length)
                                    ? idx
                                    : null;
                          });
                        },
                      ),
                      sections: List.generate(widget.counts.length, (i) {
                        final v = widget.counts[i];
                        final pct = _total == 0 ? 0.0 : (v / _total) * 100.0;
                        final touched = _touchedIndex == i;
                        return PieChartSectionData(
                          value: v,
                          color: _colors[i % _colors.length],
                          radius: sectionRadius + (touched ? bumpOut : 0.0),
                          title: '${pct.round()}%',
                          titleStyle: TextStyle(
                            fontSize: titleFont + (touched ? 1.0 : 0.0),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          titlePositionPercentageOffset: 0.66,
                        );
                      }),
                    ),
                  ),
                ),

                _CenterSummary(
                  label: si == null ? 'Total ADRs' : widget.labels[si],
                  valueText:
                      si == null
                          ? _total.toStringAsFixed(0)
                          : '${((widget.counts[si] / _total) * 100).toStringAsFixed(0)}%',
                  subtle: si == null ? 'reports' : 'of total',
                ),
              ],
            ),
          ),
        );

        final legend = _ResponsiveLegend(
          labels: widget.labels,
          values:
              widget.counts
                  .map((v) => _total == 0 ? 0.0 : (v / _total) * 100.0)
                  .toList(),
          colors: _colors,
          onTapItem: (i) {
            setState(() => _touchedIndex = (_touchedIndex == i) ? null : i);
          },
          highlightedIndex: si,
        );

        if (w >= 520) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 11, child: Center(child: donut)),
              const SizedBox(width: 32), // ↑ a bit more space to the legend
              Expanded(
                flex: 10,
                child: Align(alignment: Alignment.centerLeft, child: legend),
              ),
            ],
          );
        } else {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              donut,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: legend),
            ],
          );
        }
      },
    );
  }
}

/* ───────── Legend & Panel helpers ───────── */

class _ResponsiveLegend extends StatelessWidget {
  final List<String> labels;
  final List<double> values; // percentages 0–100
  final List<Color> colors;
  final void Function(int index)? onTapItem;
  final int? highlightedIndex;

  const _ResponsiveLegend({
    required this.labels,
    required this.values,
    required this.colors,
    this.onTapItem,
    this.highlightedIndex,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isPhone = w < 520;

    if (isPhone) {
      return Wrap(
        spacing: 10,
        runSpacing: 4,
        children: List.generate(labels.length, (i) {
          return ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
            child: _LegendItem(
              color: colors[i % colors.length],
              label: labels[i],
              pct: values[i],
              compact: true,
              onTap: onTapItem == null ? null : () => onTapItem!(i),
              highlighted: highlightedIndex == i,
            ),
          );
        }),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(labels.length, (i) {
        return _LegendItem(
          color: colors[i % colors.length],
          label: labels[i],
          pct: values[i],
          onTap: onTapItem == null ? null : () => onTapItem!(i),
          highlighted: highlightedIndex == i,
        );
      }),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final double pct; // already a percent 0–100
  final bool compact;
  final VoidCallback? onTap;
  final bool highlighted;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.pct,
    this.compact = false,
    this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final base =
        Theme.of(context).textTheme.bodyMedium ??
        const TextStyle(fontSize: 13, color: Colors.black87);
    final style = base.copyWith(
      fontSize: compact ? 12.0 : 13.0,
      fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
      color: highlighted ? Colors.black : Colors.black87,
    );

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 8 : 10,
          height: compact ? 8 : 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow:
                highlighted
                    ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)]
                    : null,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '$label  •  ${pct.toStringAsFixed(0)}%',
            style: style,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 6),
      child:
          onTap == null
              ? row
              : InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 2,
                  ),
                  child: row,
                ),
              ),
    );
  }
}

class _CenterSummary extends StatelessWidget {
  final String label;
  final String valueText;
  final String subtle;
  const _CenterSummary({
    required this.label,
    required this.valueText,
    required this.subtle,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          valueText,
          style:
              t.headlineSmall?.copyWith(fontWeight: FontWeight.w800) ??
              const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.labelLarge?.copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(subtle, style: t.labelSmall?.copyWith(color: Colors.black54)),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _Panel({required this.title, required this.child, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 520;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontSize: isPhone ? 15.0 : 16.0,
      fontWeight: FontWeight.w700,
    );
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: Colors.black54);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isPhone ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: titleStyle),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: subtitleStyle),
            ],
            SizedBox(height: isPhone ? 10 : 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline, size: 36, color: Colors.black26),
          const SizedBox(height: 8),
          Text(message, style: t.bodyMedium?.copyWith(color: Colors.black54)),
        ],
      ),
    );
  }
}
