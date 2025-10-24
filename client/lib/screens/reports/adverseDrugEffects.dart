// lib/screens/reports/adverseDrugEffects.dart

import 'dart:ui';
import 'package:flutter/material.dart';

class AdverseDrugEffectsPanel extends StatelessWidget {
  const AdverseDrugEffectsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    // Demo/static items for now; replace with your data source when wired up.
    const items = <_AdeItem>[
      _AdeItem(effect: 'Sakit Ulo', count: 1000, delta: 1),
      _AdeItem(effect: 'Masakit Tyan', count: 500, delta: -2),
      _AdeItem(effect: 'Allergy', count: 300, delta: 0),
      _AdeItem(effect: 'Groggy', count: 300, delta: 3),
    ];

    return _Panel(
      title: 'Adverse Drug Effects',
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final isPhone = w < 600;
          final baseText = Theme.of(context).textTheme.bodyMedium;

          final effectStyle = baseText?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: isPhone ? 13 : 14,
          );

          final countStyle = baseText?.copyWith(
            fontSize: isPhone ? 12 : 13,
            fontFeatures: const [FontFeature.tabularFigures()],
          );

          final rowVPadding = isPhone ? 4.0 : 6.0;
          final iconSize = isPhone ? 14.0 : 16.0;
          final gap = isPhone ? 6.0 : 8.0;

          // Use ListView with shrinkWrap so it can live inside a parent scroll view without overflow.
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(height: isPhone ? 4 : 6),
            itemBuilder: (_, i) {
              final it = items[i];
              final up = it.delta >= 0;
              final color =
                  it.delta == 0
                      ? Theme.of(context).hintColor
                      : (up ? Colors.green : Colors.red);

              return Padding(
                padding: EdgeInsets.symmetric(vertical: rowVPadding),
                child: Row(
                  children: [
                    // Effect label
                    Expanded(
                      child: Text(
                        it.effect,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: effectStyle,
                      ),
                    ),
                    // Count
                    Text(it.count.toString(), style: countStyle),
                    SizedBox(width: gap),
                    // Delta icon (up/down/flat)
                    Icon(
                      it.delta == 0
                          ? Icons.horizontal_rule
                          : (up ? Icons.arrow_upward : Icons.arrow_downward),
                      size: iconSize,
                      color: color,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Unused in layout but left here to avoid breaking imports or references.
/// You can safely remove this widget later if it’s no longer used anywhere.
class UserLeaderboardPanel extends StatelessWidget {
  const UserLeaderboardPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'User Leaderboard',
      child: Column(
        children: const [
          _UserTile(name: 'Matt Villacarlos', points: 637, rank: 1, delta: 4),
          _UserTile(name: 'Ajay Levantino', points: 637, rank: 2, delta: -2),
          _UserTile(name: 'Mikko Magtira', points: 637, rank: 3, delta: 0),
          _UserTile(name: 'Lorem Ipsum', points: 620, rank: 4, delta: 1),
        ],
      ),
    );
  }
}

/// --- Helpers (private) ---

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
              // Slightly smaller on phones to prevent wrapping
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

class _UserTile extends StatelessWidget {
  final String name;
  final int points;
  final int rank;
  final int delta; // positive up, negative down
  const _UserTile({
    required this.name,
    required this.points,
    required this.rank,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final up = delta >= 0;
    final color =
        delta == 0
            ? Theme.of(context).hintColor
            : (up ? Colors.green : Colors.red);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: CircleAvatar(
        radius: 14,
        child: Text(
          rank.toString(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: const Text('88% Correct'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$points',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            delta == 0
                ? Icons.horizontal_rule
                : (up ? Icons.arrow_upward : Icons.arrow_downward),
            size: 16,
            color: color,
          ),
          Text(
            delta.abs().toString(),
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AdeItem {
  final String effect;
  final int count;
  final int delta;
  const _AdeItem({
    required this.effect,
    required this.count,
    required this.delta,
  });
}
