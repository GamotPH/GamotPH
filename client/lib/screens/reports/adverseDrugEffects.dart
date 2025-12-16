// client/lib/screens/reports/adverseDrugEffects.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';

class AdverseDrugEffectsPanel extends ConsumerWidget {
  const AdverseDrugEffectsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pieAsync = ref.watch(adverseReactionsProvider);

    return _Panel(
      title: 'Adverse Drug Effects',
      child: pieAsync.when(
        loading:
            () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        error:
            (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Failed to load ADRs\n$e'),
            ),
        data: (series) {
          if (series.labels.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No adverse drug effects found.'),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: series.labels.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final label = series.labels[i];
              final value = series.values[i].toInt();
              final hasBreakdown = series.breakdowns.containsKey(label);

              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap:
                    hasBreakdown
                        ? () => _showBreakdownModal(
                          context,
                          label,
                          series.breakdowns[label]!,
                        )
                        : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration:
                                hasBreakdown ? TextDecoration.underline : null,
                          ),
                        ),
                      ),
                      Text(
                        value.toString(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (hasBreakdown)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.chevron_right, size: 18),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// 🔍 Drill-down modal for Unmapped / Other
void _showBreakdownModal(
  BuildContext context,
  String title,
  Map<String, int> items,
) {
  final entries =
      items.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (_, i) {
                  final e = entries[i];
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        e.value.toString(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// --- Panel wrapper (UNCHANGED) ---
class _Panel extends StatelessWidget {
  final String title;
  final Widget child;
  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 600;
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
                fontWeight: FontWeight.w700,
                fontSize: isPhone ? 15 : 16,
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
