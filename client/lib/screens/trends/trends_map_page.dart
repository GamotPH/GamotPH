// lib/screens/trends/trends_map_page.dart

import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../data/providers.dart';
import '../../data/analytics_repository.dart' show TrendCluster;
import '../../data/adr_alias.dart';

class TrendsMapPage extends ConsumerStatefulWidget {
  const TrendsMapPage({super.key});

  @override
  ConsumerState<TrendsMapPage> createState() => _TrendsMapPageState();
}

class _TrendsMapPageState extends ConsumerState<TrendsMapPage> {
  // ---------------- FILTER STATE (ONLY CHANGE) ----------------
  String _selectedMedicine = 'ALL'; // canonical generic only

  // ---------------- EXISTING STATE (UNCHANGED) ----------------
  String? _regionCode;

  DateTimeRange _range = DateTimeRange(
    start: DateTime(DateTime.now().year, 1, 1),
    end: DateTime(DateTime.now().year, 12, 31),
  );

  final LatLng _initialCenter = const LatLng(12.8797, 121.7740);
  final double _initialZoom = 6.0;

  final MapController _mapController = MapController();
  double _zoom = 9.5;
  LatLngBounds? _selectedBounds;
  bool _mapReady = false;

  @override
  Widget build(BuildContext context) {
    // ---------------- DATA ----------------
    final regionsAsync = ref.watch(
      adminAreasProvider((level: AreaLevel.region, parentCode: null)),
    );

    final genericsAsync = ref.watch(canonicalGenericMedicinesProvider);

    // ---------------- TRENDS PARAMS (FILTER CHANGE ONLY) ----------------
    final params = TrendsParams(
      areaCode: _regionCode,
      start: _range.start.toUtc(),
      end: _range.end.toUtc(),
      genericName: _selectedMedicine == 'ALL' ? null : _selectedMedicine,
    );

    final trendsAsync = ref.watch(trendsProvider(params));

    return Scaffold(
      backgroundColor: const Color(0xFFF1EEF4),
      body: SafeArea(
        child: Row(
          children: [
            // ================= LEFT FILTER =================
            SizedBox(
              width: 320,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                      children: [
                        const _PanelHeader(title: 'Map Screen'),
                        const SizedBox(height: 8),

                        // -------- Region --------
                        _LabeledField(
                          label: 'Region',
                          child: _Box(
                            child: regionsAsync.when(
                              loading: () => const _LoadingStrip(),
                              error: (e, _) => _Err('regions', e),
                              data: (regions) {
                                _ensureSelectionExists(
                                  itemsCodes: regions.map((e) => e.code),
                                  current: _regionCode,
                                  clear: () {
                                    setState(() => _regionCode = null);
                                    _updateBoundsAndPan();
                                  },
                                );

                                return DropdownButtonFormField<String?>(
                                  value: _regionCode,
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('ALL'),
                                    ),
                                    ...regions.map(
                                      (r) => DropdownMenuItem(
                                        value: r.code,
                                        child: Text(
                                          r.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (code) {
                                    setState(() {
                                      _regionCode = code;
                                      _selectedBounds = null;
                                    });
                                    _updateBoundsAndPan();
                                  },
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // -------- Date --------
                        _LabeledField(
                          label: 'Date',
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2022, 1, 1),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                                initialDateRange: _range,
                              );
                              if (picked != null) {
                                setState(() => _range = picked);
                              }
                            },
                            child: _Box(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_month_outlined,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${DateFormat('MM/dd/yy').format(_range.start)} - '
                                      '${DateFormat('MM/dd/yy').format(_range.end)}',
                                    ),
                                  ),
                                  const Icon(Icons.edit_calendar, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // -------- Medicine (Generic Only) --------
                        _LabeledField(
                          label: 'Medicine (Generic)',
                          child: _Box(
                            child: genericsAsync.when(
                              loading: () => const _LoadingStrip(),
                              error: (e, _) => _Err('medicines', e),
                              data: (list) {
                                final options = ['ALL', ...list];

                                if (!options.contains(_selectedMedicine)) {
                                  _selectedMedicine = 'ALL';
                                }

                                return DropdownButtonFormField<String>(
                                  value: _selectedMedicine,
                                  isExpanded: true,
                                  items:
                                      options
                                          .map(
                                            (e) => DropdownMenuItem(
                                              value: e,
                                              child: Text(e),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (v) {
                                    setState(() {
                                      _selectedMedicine = v ?? 'ALL';
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        Text('Top Side Effects', style: _Styles.sectionTitle),
                        const SizedBox(height: 8),

                        // -------- Effects --------
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Material(
                            color: Colors.white,
                            child: trendsAsync.when(
                              loading:
                                  () => const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                              error:
                                  (e, _) => Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'Failed to load trends.\n$e',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              data: (res) {
                                final Map<String, int> counts = {};
                                final Map<String, Set<String>> drugsByEffect =
                                    {};

                                for (final t in res.topEffects) {
                                  final rawEffect = t.effect.trim();

                                  if (rawEffect.isEmpty) continue;
                                  if (rawEffect.toLowerCase() == 'unknown' ||
                                      rawEffect.toLowerCase() ==
                                          'unspecified') {
                                    continue;
                                  }

                                  // 🔑 CANONICALIZE EFFECT ONLY
                                  final canonicalEffect = normalizeAdrAlias(
                                    rawEffect,
                                  );

                                  counts[canonicalEffect] =
                                      (counts[canonicalEffect] ?? 0) + t.cases;

                                  // 🔑 Track drugs only for display
                                  if (t.drug.trim().isNotEmpty) {
                                    drugsByEffect
                                        .putIfAbsent(
                                          canonicalEffect,
                                          () => <String>{},
                                        )
                                        .add(t.drug.trim());
                                  }
                                }

                                if (counts.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: Text(
                                        'No side effects for this selection.',
                                      ),
                                    ),
                                  );
                                }

                                final list =
                                    counts.entries
                                        .map(
                                          (e) => (
                                            effect: e.key,
                                            cases: e.value,
                                            drugs:
                                                drugsByEffect[e.key] ??
                                                const <String>{},
                                          ),
                                        )
                                        .toList()
                                      ..sort(
                                        (a, b) => b.cases.compareTo(a.cases),
                                      );

                                return SizedBox(
                                  height: 320,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: list.length,
                                    separatorBuilder:
                                        (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (context, i) {
                                      final t = list[i];

                                      final subtitle =
                                          _selectedMedicine == 'ALL'
                                              ? (t.drugs.length == 1
                                                  ? t.drugs.first
                                                  : 'Multiple medicines')
                                              : _selectedMedicine;

                                      return _EffectTile(
                                        effect: t.effect, // BIG text
                                        drug: subtitle, // small text
                                        cases: t.cases,
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF7C245),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _printTrendMap,
                        child: const Text(
                          'Print Trend Map',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ================= MAP =================
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                child: Stack(
                  children: [
                    // ================= MAP CONTAINER =================
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF2E7BD9),
                          width: 4,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _initialCenter,
                            initialZoom: _initialZoom,
                            onMapReady: () {
                              _mapReady = true;
                              _updateBoundsAndPan();
                            },
                            onMapEvent: (evt) {
                              final z = evt.camera.zoom;
                              if (z != _zoom) setState(() => _zoom = z);
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.gamotph.app',
                            ),

                            trendsAsync.maybeWhen(
                              data: (res) {
                                if (_regionCode != null &&
                                    _selectedBounds == null) {
                                  return const SizedBox.shrink();
                                }
                                return CircleLayer(
                                  circles: _buildHeatCirclesFiltered(
                                    res.clusters,
                                    bounds: _selectedBounds,
                                    zoom: _zoom,
                                  ),
                                );
                              },
                              orElse: () => const SizedBox.shrink(),
                            ),

                            trendsAsync.maybeWhen(
                              data: (res) {
                                if (_regionCode != null &&
                                    _selectedBounds == null) {
                                  return const SizedBox.shrink();
                                }
                                return MarkerLayer(
                                  markers: _buildHeatMarkersFiltered(
                                    res.clusters,
                                    bounds: _selectedBounds,
                                    zoom: _zoom,
                                  ),
                                );
                              },
                              orElse: () => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ================= LEGEND OVERLAY (ADD THIS) =================
                    const Positioned(
                      bottom: 16,
                      right: 16,
                      child: _HeatLegend(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= HELPERS (UNCHANGED) =================
  Future<void> _updateBoundsAndPan() async {
    if (!_mapReady) return;

    final code = _regionCode;
    if (code == null) {
      setState(() => _selectedBounds = null);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(_initialCenter, 6.0);
      });
      return;
    }

    final bbox = await ref.read(repoProvider).adminBounds(code);
    if (!mounted || bbox == null) return;

    setState(() => _selectedBounds = bbox);

    _mapController.fitCamera(
      CameraFit.bounds(bounds: bbox, padding: const EdgeInsets.all(12)),
    );
  }

  String _buildTooltip(TrendCluster c) {
    final buffer = StringBuffer();
    buffer.writeln('Total reports: ${c.count}');
    if (c.effectCounts.isNotEmpty) {
      buffer.writeln('\nTop symptoms:');
      final sorted =
          c.effectCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in sorted.take(3)) {
        buffer.writeln('• ${e.key} (${e.value})');
      }
    }
    return buffer.toString();
  }

  List<CircleMarker> _buildHeatCirclesFiltered(
    List<TrendCluster> clusters, {
    LatLngBounds? bounds,
    required double zoom,
  }) {
    if (clusters.isEmpty) return const [];
    int minC = clusters.first.count, maxC = clusters.first.count;
    for (final c in clusters) {
      minC = math.min(minC, c.count);
      maxC = math.max(maxC, c.count);
    }
    final denom = (maxC - minC) == 0 ? 1 : (maxC - minC);
    return clusters
        .where((c) => bounds == null || _insideBounds(bounds, c.center))
        .map((c) {
          final t = (c.count - minC) / denom;
          final color = _heatColor(t);
          final r = _radiusForZoom(zoom, c.count);
          return CircleMarker(
            point: c.center,
            radius: r,
            useRadiusInMeter: false,
            color: color.withValues(alpha: 0.55),
            borderColor: color.withValues(alpha: 0.75),
            borderStrokeWidth: 1.8,
          );
        })
        .toList();
  }

  List<Marker> _buildHeatMarkersFiltered(
    List<TrendCluster> clusters, {
    LatLngBounds? bounds,
    required double zoom,
  }) {
    if (clusters.isEmpty) return const [];
    int minC = clusters.first.count, maxC = clusters.first.count;
    for (final c in clusters) {
      minC = math.min(minC, c.count);
      maxC = math.max(maxC, c.count);
    }
    final denom = (maxC - minC) == 0 ? 1 : (maxC - minC);
    return clusters
        .where((c) => bounds == null || _insideBounds(bounds, c.center))
        .map((c) {
          final t = (c.count - minC) / denom;
          final color = _heatColor(t);
          final r = _radiusForZoom(zoom, c.count);
          return Marker(
            point: c.center,
            width: r * 2,
            height: r * 2,
            child: Tooltip(
              message: _buildTooltip(c),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.55),
                  border: Border.all(
                    color: color.withValues(alpha: 0.75),
                    width: 1.8,
                  ),
                ),
              ),
            ),
          );
        })
        .toList();
  }

  bool _insideBounds(LatLngBounds b, LatLng p) =>
      p.latitude >= b.south &&
      p.latitude <= b.north &&
      p.longitude >= b.west &&
      p.longitude <= b.east;

  double _radiusForZoom(double zoom, int count) {
    final t = ((zoom - 6) / 8).clamp(0.0, 1.0);
    return 8 + (24 * t) + (math.log(count + 1) / math.ln10) * 2;
  }

  static Color _heatColor(double t) {
    if (t < 0.5) {
      return Color.lerp(Colors.green, Colors.yellow, t / 0.5)!;
    }
    return Color.lerp(Colors.yellow, Colors.red, (t - 0.5) / 0.5)!;
  }

  void _printTrendMap() {
    if (kIsWeb) {
      importForWebPrint();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printing available on web only')),
      );
    }
  }

  void _ensureSelectionExists({
    required Iterable<String> itemsCodes,
    required String? current,
    required VoidCallback clear,
  }) {
    if (current != null && !itemsCodes.contains(current)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) clear();
      });
    }
  }
}

// ================= SMALL UI HELPERS =================

void importForWebPrint() => _webPrint();

@pragma('wasm:entry-point')
void _webPrint() {}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      color: Colors.black54,
    ),
  );
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: _Styles.fieldLabel),
      const SizedBox(height: 6),
      child,
    ],
  );
}

class _Box extends StatelessWidget {
  const _Box({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFCFD4E2)),
    ),
    child: child,
  );
}

class _EffectTile extends StatelessWidget {
  final String drug; // small text (medicine)
  final String effect; // big text (side effect)
  final int cases;

  const _EffectTile({
    required this.drug,
    required this.effect,
    required this.cases,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
    ),
    child: Row(
      children: [
        const Icon(Icons.medical_services, color: Colors.blue),
        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ BIG: SIDE EFFECT
              Text(
                effect,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 2),

              // ✅ SMALL: MEDICINE(S)
              Text(
                drug,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
        ),

        Text(
          cases.toString(),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _HeatLegend extends StatelessWidget {
  const _HeatLegend();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Legend', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _legendRow(Colors.green, 'Low reports'),
            _legendRow(Colors.yellow, 'Medium reports'),
            _legendRow(Colors.red, 'High reports'),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _LoadingStrip extends StatelessWidget {
  const _LoadingStrip();
  @override
  Widget build(BuildContext context) =>
      const LinearProgressIndicator(minHeight: 2);
}

class _Err extends StatelessWidget {
  final String what;
  final Object error;
  const _Err(this.what, this.error);
  @override
  Widget build(BuildContext context) => Text(
    'Failed to load $what:\n$error',
    style: const TextStyle(fontSize: 12),
  );
}

class _Styles {
  static const fieldLabel = TextStyle(
    fontWeight: FontWeight.w700,
    color: Colors.black87,
  );
  static const sectionTitle = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 16,
  );
}

class _SideEffectRow {
  final String effect;
  final int cases;

  const _SideEffectRow({required this.effect, required this.cases});
}
