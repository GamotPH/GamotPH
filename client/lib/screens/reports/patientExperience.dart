// lib/screens/reports/patientExperience.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// word_cloud package
import 'package:word_cloud/word_cloud_data.dart';
import 'package:word_cloud/word_cloud_view.dart';

import '../../data/providers.dart'; // uses wordCloudProvider (List<WordItem>)

class PatientExperiencePanel extends ConsumerWidget {
  /// Fixed panel height so layout is stable inside the dashboard.
  final double height;
  const PatientExperiencePanel({super.key, this.height = 240});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordsAsync = ref.watch(wordCloudProvider);

    return _Panel(
      title: 'Patient Experience',
      child: SizedBox(
        height: height,
        child: wordsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Failed to load: $e')),
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                child: Text('No data in the selected range.'),
              );
            }

            // 1) Clean + shorten labels so they never become ultra-wide.
            //    - trim whitespace
            //    - if longer than ~22 chars, keep at most 2 words
            //      and hard-cap length to 22.
            final List<Map<String, Object>> wordList = [];
            for (final w in items) {
              var label = w.text.trim();
              if (label.isEmpty) continue;

              if (label.length > 22) {
                final parts = label.split(RegExp(r'\s+'));
                if (parts.length > 1) {
                  label = parts.take(2).join(' ');
                }
                if (label.length > 22) {
                  label = label.substring(0, 22);
                }
              }

              wordList.add(<String, Object>{
                'word': label,
                'value': w.weight, // frequency
              });
            }

            if (wordList.isEmpty) {
              return const Center(
                child: Text('No data in the selected range.'),
              );
            }

            final wcData = WordCloudData(data: wordList);

            return LayoutBuilder(
              builder: (context, constraints) {
                // Safe, positive drawing area
                final width =
                    (constraints.maxWidth.isFinite && constraints.maxWidth > 0)
                        ? constraints.maxWidth
                        : 400.0;
                final height =
                    (constraints.maxHeight.isFinite &&
                            constraints.maxHeight > 0)
                        ? constraints.maxHeight
                        : 240.0;

                return Center(
                  child: WordCloudView(
                    data: wcData,
                    mapwidth: width,
                    mapheight: height,
                    fontWeight: FontWeight.bold,
                    colorlist: const [
                      Color(0xFF1A73E8), // blue
                      Color(0xFF34A853), // green
                      Color(0xFFEA4335), // red
                      Color(0xFFFBBC04), // yellow
                      Color(0xFF8E24AA), // purple
                      Color(0xFF00ACC1), // teal
                      Color(0xFFEF6C00), // orange
                      Color(0xFF5E35B1), // deep purple
                    ],
                    mapcolor: Colors.transparent,
                    // Smaller range so long labels don't overflow the box
                    mintextsize: 10,
                    maxtextsize: 26,
                  ),
                );
              },
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
