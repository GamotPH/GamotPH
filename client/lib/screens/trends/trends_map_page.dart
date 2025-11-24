import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../data/providers.dart';
import '../../data/analytics_repository.dart' show TrendCluster;

class TrendsMapPage extends ConsumerStatefulWidget {
  const TrendsMapPage({super.key});
  @override
  ConsumerState<TrendsMapPage> createState() => _TrendsMapPageState();
}

class _TrendsMapPageState extends ConsumerState<TrendsMapPage> {
  // Local (widget) filter state
  String _selectedGeneric = 'ALL';
  String _selectedBrand = 'ALL';

  // Linked area selection (null == ALL) — REGION ONLY
  String? _regionCode;

  DateTimeRange _range = DateTimeRange(
    start: DateTime(DateTime.now().year, 1, 1),
    end: DateTime(DateTime.now().year, 12, 31),
  );

  // Map defaults — show the whole Philippines at first paint
  final LatLng _initialCenter = const LatLng(12.8797, 121.7740);
  final double _initialZoom = 6.0;

  // Map controller + dynamic sizing
  final MapController _mapController = MapController();
  double _zoom = 9.5;
  LatLngBounds? _selectedBounds; // active bbox of chosen area (null = ALL)
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    // Don't move the camera here; do it in onMapReady once the map has a real size.
  }

  @override
  Widget build(BuildContext context) {
    // Region dropdown options
    final regionsAsync = ref.watch(
      adminAreasProvider((level: AreaLevel.region, parentCode: null)),
    );

    // Region-only area code
    final String? areaCode = _regionCode;

    // Drug filters
    final genericsAsync = ref.watch(genericNameListProvider(_selectedBrand));
    final brandsAsync = ref.watch(brandNameListProvider(_selectedGeneric));

    // Trends query (server already receives areaCode; we also guard on the client with bbox)
    final params = TrendsParams(
      areaCode: areaCode,
      start: _range.start.toUtc(),
      end: _range.end.toUtc(),
      genericName: (_selectedGeneric == 'ALL') ? null : _selectedGeneric,
      brandName: (_selectedBrand == 'ALL') ? null : _selectedBrand,
    );
    final trendsAsync = ref.watch(trendsProvider(params));

    return Scaffold(
      backgroundColor: const Color(0xFFF1EEF4),
      body: SafeArea(
        child: Row(
          children: [
            // ------------------------- LEFT FILTER RAIL -------------------------
            SizedBox(
              width: 320,
              child: Column(
                children: [
                  // Scrollable content
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                      children: [
                        const _PanelHeader(title: 'Map Screen'),
                        const SizedBox(height: 8),

                        // ---------------- Region ----------------
                        _LabeledField(
                          label: 'Region',
                          child: _Box(
                            child: regionsAsync.when(
                              loading: () => const _LoadingStrip(),
                              error: (e, _) => _Err('regions', e),
                              data: (regions) {
                                // Ensure current selection exists
                                _ensureSelectionExists(
                                  itemsCodes: regions.map((e) => e.code),
                                  current: _regionCode,
                                  clear: () {
                                    setState(() {
                                      _regionCode = null;
                                    });
                                    _updateBoundsAndPan();
                                  },
                                );

                                final items = <DropdownMenuItem<String?>>[
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('ALL'),
                                  ),
                                  ...regions.map(
                                    (r) => DropdownMenuItem<String?>(
                                      value: r.code,
                                      child: Text(
                                        r.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ];
                                return DropdownButtonFormField<String?>(
                                  value: _regionCode,
                                  isExpanded: true,
                                  items: items,
                                  onChanged: (code) {
                                    setState(() {
                                      _regionCode = code;
                                      _selectedBounds = null; // reset guard
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

                        // ---------------- Date range ----------------
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

                        // ---------------- Generic Name ----------------
                        _LabeledField(
                          label: 'Generic Name',
                          child: _Box(
                            child: genericsAsync.when(
                              loading: () => const _LoadingStrip(),
                              error: (e, _) => _Err('generics', e),
                              data: (list) {
                                final options =
                                    <String>{...list, 'ALL'}.toList()
                                      ..sort((a, b) {
                                        if (a == 'ALL') return -1;
                                        if (b == 'ALL') return 1;
                                        return a.toLowerCase().compareTo(
                                          b.toLowerCase(),
                                        );
                                      });
                                final value =
                                    options.contains(_selectedGeneric)
                                        ? _selectedGeneric
                                        : 'ALL';
                                return DropdownButtonFormField<String>(
                                  value: value,
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
                                  onChanged:
                                      (v) => setState(
                                        () => _selectedGeneric = v ?? 'ALL',
                                      ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ---------------- Brand Name ----------------
                        _LabeledField(
                          label: 'Brand Name',
                          child: _Box(
                            child: brandsAsync.when(
                              loading: () => const _LoadingStrip(),
                              error: (e, _) => _Err('brands', e),
                              data: (list) {
                                final options =
                                    <String>{...list, 'ALL'}.toList()
                                      ..sort((a, b) {
                                        if (a == 'ALL') return -1;
                                        if (b == 'ALL') return 1;
                                        return a.toLowerCase().compareTo(
                                          b.toLowerCase(),
                                        );
                                      });
                                final value =
                                    options.contains(_selectedBrand)
                                        ? _selectedBrand
                                        : 'ALL';
                                return DropdownButtonFormField<String>(
                                  value: value,
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
                                  onChanged:
                                      (v) => setState(
                                        () => _selectedBrand = v ?? 'ALL',
                                      ),
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

                        // --------- Effects list ---------
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
                                final list = res.topEffects;
                                if (list.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: Text('No data for this filter.'),
                                    ),
                                  );
                                }
                                return SizedBox(
                                  height: 320,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: list.length,
                                    separatorBuilder:
                                        (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (context, i) {
                                      final t = list[i];
                                      return _EffectTile(
                                        drug:
                                            t.drug.isEmpty ? 'Unknown' : t.drug,
                                        effect:
                                            t.effect.isEmpty
                                                ? 'Unspecified'
                                                : t.effect,
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

                  // Pinned button at the bottom
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

            // ------------------------------- MAP --------------------------------
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                child: Stack(
                  children: [
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
                              _updateBoundsAndPan(); // align camera to ALL or region bbox
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

                            // NOTE: We intentionally DO NOT draw the blue bbox rectangle anymore.

                            // Heat circles (strictly inside bbox when a specific area is chosen)
                            trendsAsync.maybeWhen(
                              data: (res) {
                                final bool showingAll = _regionCode == null;
                                // If a specific area is selected but we don't have its bbox yet,
                                // hide the circles to avoid leaking markers from the previous area.
                                if (!showingAll && _selectedBounds == null) {
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
                          ],
                        ),
                      ),
                    ),

                    // Heat legend
                    Positioned(
                      top: 16,
                      right: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 6),
                          ],
                        ),
                        child: Row(
                          children: [
                            _legendSwatch(_heatColor(0.2), 'Low'),
                            const SizedBox(width: 8),
                            _legendSwatch(_heatColor(0.6), 'Med'),
                            const SizedBox(width: 8),
                            _legendSwatch(_heatColor(1.0), 'High'),
                          ],
                        ),
                      ),
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

  // ---------------------- bounds + camera helpers ----------------------
  Future<void> _updateBoundsAndPan() async {
    if (!_mapReady) return; // avoid moving before map layout is ready

    final String? code = _regionCode;

    // If ALL is selected, clear bounds and zoom out to whole PH
    if (code == null) {
      setState(() => _selectedBounds = null);

      // Move after current frame to be extra safe
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(const LatLng(12.8797, 121.7740), 6.0);
      });
      return;
    }

    // Fetch bbox for the selected code
    final bbox = await ref.read(repoProvider).adminBounds(code);

    if (!mounted) return;

    if (bbox == null) {
      // Important: clear bounds when the lookup fails so we don't reuse an old bbox.
      setState(() => _selectedBounds = null);
      return;
    }

    setState(() => _selectedBounds = bbox);

    // Fit camera to bbox
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bbox,
        padding: const EdgeInsets.only(
          left: 12,
          right: 12,
          top: 12,
          bottom: 12,
        ),
      ),
    );
  }

  // --------------------------- heat helpers ---------------------------
  // Keep circles visible at any zoom (pixel radius), and clamp to selected bounds.
  List<CircleMarker> _buildHeatCirclesFiltered(
    List<TrendCluster> clusters, {
    LatLngBounds? bounds,
    required double zoom,
  }) {
    if (clusters.isEmpty) return const <CircleMarker>[];

    int minC = clusters.first.count;
    int maxC = clusters.first.count;
    for (final c in clusters) {
      if (c.count < minC) minC = c.count;
      if (c.count > maxC) maxC = c.count;
    }
    final denom = (maxC - minC) == 0 ? 1.0 : (maxC - minC).toDouble();

    final items = <CircleMarker>[];
    for (final c in clusters) {
      if (bounds != null && !_insideBounds(bounds, c.center)) continue;

      final t = (c.count - minC) / denom;
      final color = _heatColor(t);
      final px = _radiusForZoom(zoom, c.count); // pixel radius

      items.add(
        CircleMarker(
          point: c.center,
          useRadiusInMeter: false, // pixel-based so it scales with zoom
          radius: px,
          color: color.withValues(alpha: 0.55),
          borderColor: color.withValues(alpha: 0.75),
          borderStrokeWidth: 1.8,
        ),
      );
    }
    return items;
  }

  bool _insideBounds(LatLngBounds b, LatLng p) {
    return p.latitude >= b.south &&
        p.latitude <= b.north &&
        p.longitude >= b.west &&
        p.longitude <= b.east;
  }

  // zoom -> pixel radius (smooth growth between z=6..14)
  double _radiusForZoom(double zoom, int count) {
    final t = ((zoom - 6.0) / 8.0).clamp(0.0, 1.0); // 6..14 -> 0..1
    final base = 8.0 + (24.0 * t); // 8..32 px
    final bonus = (math.log(count + 1) / math.ln10) * 2.0; // small emphasis
    return base + bonus;
  }

  static Color _heatColor(double t) {
    t = t.clamp(0.0, 1.0);
    if (t < 0.5) {
      final k = t / 0.5;
      return Color.lerp(Colors.green, Colors.yellow, k)!;
    } else {
      final k = (t - 0.5) / 0.5;
      return Color.lerp(Colors.yellow, Colors.red, k)!;
    }
  }

  Widget _legendSwatch(Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  );

  void _printTrendMap() {
    if (kIsWeb) {
      importForWebPrint();
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Printing is available on web; mobile/desktop coming soon.',
          ),
        ),
      );
    }
  }

  // ---- selection validity helper ----
  void _ensureSelectionExists({
    required Iterable<String> itemsCodes,
    required String? current,
    required VoidCallback clear,
  }) {
    if (current == null) return;
    final exists = itemsCodes.any((c) => c == current);
    if (!exists) {
      // Clear *after* this frame to avoid setState during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) clear();
      });
    }
  }
}

// web print shim
void importForWebPrint() {
  _webPrint();
}

@pragma('wasm:entry-point')
void _webPrint() {}

// --------- small UI helpers ----------
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
  final String drug;
  final String effect;
  final int cases;

  const _EffectTile({
    required this.drug,
    required this.effect,
    required this.cases,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.medical_services, color: Colors.blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  drug,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  effect,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'No. of Cases',
                style: TextStyle(color: Colors.black45, fontSize: 11),
              ),
              Text(
                cases.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingStrip extends StatelessWidget {
  const _LoadingStrip();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: LinearProgressIndicator(minHeight: 2),
  );
}

class _Err extends StatelessWidget {
  final String what;
  final Object error;
  const _Err(this.what, this.error);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8.0),
    child: Text(
      'Failed to load $what:\n$error',
      style: const TextStyle(fontSize: 12),
    ),
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
