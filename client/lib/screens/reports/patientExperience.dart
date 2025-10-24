// lib/screens/reports/patientExperience.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart'; // uses wordCloudProvider

class PatientExperiencePanel extends ConsumerWidget {
  /// Fixed panel height so Column -> Stack never sees infinite height.
  final double height;
  const PatientExperiencePanel({super.key, this.height = 240});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordsAsync = ref.watch(wordCloudProvider);

    return _Panel(
      title: 'Patient Experience',
      subtitle: 'IVATAN | CEBUANO | FILIPINO | ILOKANO | ENGLISH',
      child: SizedBox(
        height: height,
        child: wordsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Failed to load: $e')),
          data: (items) {
            // items is List<WordItem>
            if (items.isEmpty) {
              return const Center(
                child: Text('No data in the selected range.'),
              );
            }
            final map = <String, int>{
              for (final w in items)
                if (w.text.trim().isNotEmpty) w.text.trim(): w.weight,
            };
            final seed = map.hashCode;
            return _WordCloudScatter(
              words: map,
              minFont: 12,
              maxFont: 42,
              seed: seed,
            );
          },
        ),
      ),
    );
  }
}

/// ---------------- Panel shell ----------------
class _Panel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _Panel({required this.title, this.subtitle, required this.child});

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
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: isPhone ? 11.0 : 12.0,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            SizedBox(height: isPhone ? 10 : 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// --------------- Scatter word cloud ----------------
/// (Your existing layout code, unchanged)
class _WordCloudScatter extends StatefulWidget {
  final Map<String, int> words;
  final double minFont;
  final double maxFont;
  final int? seed;

  const _WordCloudScatter({
    required this.words,
    this.minFont = 12,
    this.maxFont = 42,
    this.seed,
  });

  @override
  State<_WordCloudScatter> createState() => _WordCloudScatterState();
}

class _WordCloudScatterState extends State<_WordCloudScatter> {
  Size? _lastSize;
  List<_PlacedWord> _placed = [];

  static const _palette = <Color>[
    Color(0xFF1A73E8), // blue
    Color(0xFF34A853), // green
    Color(0xFFEA4335), // red
    Color(0xFFFBBC04), // amber
    Color(0xFF8E24AA), // purple
    Color(0xFF00ACC1), // teal
    Color(0xFFEF6C00), // deep orange
    Color(0xFF5E35B1), // deep purple
    Color(0xFF0F9D58), // deep green
    Color(0xFFDB4437), // alt red
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width =
            constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.of(context).size.width;

        final double height =
            (constraints.hasBoundedHeight && constraints.maxHeight.isFinite)
                ? (constraints.maxHeight.clamp(160.0, 800.0) as double)
                : 240.0;

        final size = Size(width, height);

        if (_lastSize != size) {
          _placed = _layoutWords(size);
          _lastSize = size;
        }

        return SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            children:
                _placed
                    .map(
                      (w) => Positioned(
                        left: w.offset.dx,
                        top: w.offset.dy,
                        child: Text(
                          w.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: w.fontSize,
                            fontWeight:
                                w.isHeavy ? FontWeight.w800 : FontWeight.w700,
                            color: w.color,
                            letterSpacing: 0.2,
                            height: 1.0,
                            shadows: const [
                              Shadow(
                                blurRadius: 0.2,
                                color: Colors.black12,
                                offset: Offset(0, 0.2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        );
      },
    );
  }

  List<_PlacedWord> _layoutWords(Size area) {
    if (widget.words.isEmpty) return const <_PlacedWord>[];

    final entries =
        widget.words.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final maxW = entries.first.value.toDouble();
    final minW = entries.last.value.toDouble();

    double mapSize(int w) {
      if (maxW == minW) return (widget.minFont + widget.maxFont) / 2;
      final t = (w - minW) / (maxW - minW);
      final eased = Curves.easeOut.transform(t);
      return widget.minFont + (widget.maxFont - widget.minFont) * eased;
    }

    final rnd = Random(widget.seed ?? widget.words.hashCode);
    final placed = <_PlacedWord>[];
    final boxes = <Rect>[];

    const margin = 6.0;
    const edgePad = 10.0;

    for (var i = 0; i < entries.length; i++) {
      final text = entries[i].key;
      final fontSize = mapSize(entries[i].value);
      final color = _palette[i % _palette.length];
      final isHeavy = entries[i].value >= (maxW * 0.7);

      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isHeavy ? FontWeight.w800 : FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final w = tp.width;
      final h = tp.height;

      if (w > area.width - 2 * edgePad) continue;

      const maxAttempts = 350;
      Rect? rect;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        final cx = area.width / 2, cy = area.height / 2;
        final rx = (rnd.nextDouble() - 0.5);
        final ry = (rnd.nextDouble() - 0.5);
        final bias = 0.72;
        final x = cx + rx * area.width * bias - w / 2;
        final y = cy + ry * area.height * bias - h / 2;

        final clamped = Offset(
          x.clamp(edgePad, area.width - w - edgePad),
          y.clamp(edgePad, area.height - h - edgePad),
        );

        final candidate = Rect.fromLTWH(
          clamped.dx - margin,
          clamped.dy - margin,
          w + 2 * margin,
          h + 2 * margin,
        );

        final overlaps = boxes.any((b) => b.overlaps(candidate));
        if (!overlaps) {
          rect = candidate;
          break;
        }
      }

      if (rect == null) continue;

      boxes.add(rect);
      placed.add(
        _PlacedWord(
          text: text,
          fontSize: fontSize,
          color: color,
          isHeavy: isHeavy,
          offset: Offset(rect.left + margin, rect.top + margin),
        ),
      );
    }

    return placed;
  }
}

class _PlacedWord {
  final String text;
  final double fontSize;
  final Color color;
  final bool isHeavy;
  final Offset offset;

  const _PlacedWord({
    required this.text,
    required this.fontSize,
    required this.color,
    required this.isHeavy,
    required this.offset,
  });

  @override
  String toString() =>
      '_PlacedWord(text: $text, fontSize: $fontSize, offset: $offset)';
}
