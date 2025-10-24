import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../data/providers.dart';
import '../../data/analytics_repository.dart' show TrendCluster, AdminArea;

class TrendsMapPage extends ConsumerStatefulWidget {
  const TrendsMapPage({super.key});
  @override
  ConsumerState<TrendsMapPage> createState() => _TrendsMapPageState();
}

class _TrendsMapPageState extends ConsumerState<TrendsMapPage> {
  // Local (widget) filter state
  String _selectedGeneric = 'ALL';
  String _selectedBrand = 'ALL';

  // Linked area selections (null == ALL)
  String? _regionCode;
  String? _provinceCode;
  String? _cityCode;

  DateTimeRange _range = DateTimeRange(
    start: DateTime(DateTime.now().year, 1, 1),
    end: DateTime(DateTime.now().year, 12, 31),
  );

  // Map defaults
  final LatLng _initialCenter = const LatLng(14.6760, 121.0437);
  final double _initialZoom = 9.5;

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${DateFormat('MM/dd/yy').format(_range.start)} - ${DateFormat('MM/dd/yy').format(_range.end)}';

    // Lists for the three dropdowns
    final regionsAsync = ref.watch(
      adminAreasProvider((level: AreaLevel.region, parentCode: null)),
    );

    final provincesAsync = ref.watch(
      adminAreasProvider((level: AreaLevel.province, parentCode: _regionCode)),
    );

    // Use the NEW provider that understands province OR region as parent.
    // Cities depend on Province if chosen, otherwise Region; ALL => all cities.
    // Cities/Municipalities: province takes priority; else region; else ALL
    final citiesAsync = ref.watch(
      adminAreasProvider((
        level: AreaLevel.city,
        parentCode: _provinceCode ?? _regionCode, // null => ALL cities
      )),
    );
    // Most specific area wins
    final String? areaCode = _cityCode ?? _provinceCode ?? _regionCode;

    // Drug filters
    final genericsAsync = ref.watch(genericNameListProvider(_selectedBrand));
    final brandsAsync = ref.watch(brandNameListProvider(_selectedGeneric));

    // Trends query
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
                              loading:
                                  () => const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: LinearProgressIndicator(
                                      minHeight: 2,
                                    ),
                                  ),
                              error:
                                  (e, _) => Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      'Failed to load regions:\n$e',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                              data: (regions) {
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
                                      _provinceCode = null;
                                      _cityCode = null;
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
                        const SizedBox(height: 12),

                        // ---------------- Province ----------------
                        _LabeledField(
                          label: 'Province',
                          child: _Box(
                            child: provincesAsync.when(
                              loading:
                                  () => const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: LinearProgressIndicator(
                                      minHeight: 2,
                                    ),
                                  ),
                              error:
                                  (e, _) => Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      'Failed to load provinces:\n$e',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                              data: (provinces) {
                                final items = <DropdownMenuItem<String?>>[
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('ALL'),
                                  ),
                                  ...provinces.map(
                                    (p) => DropdownMenuItem<String?>(
                                      value: p.code,
                                      child: Text(
                                        p.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ];
                                return DropdownButtonFormField<String?>(
                                  value: _provinceCode,
                                  isExpanded: true,
                                  items: items,
                                  onChanged: (code) {
                                    setState(() {
                                      _provinceCode = code;
                                      _cityCode = null;
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
                        const SizedBox(height: 12),

                        // ---------------- City/Municipality ----------------
                        _LabeledField(
                          label: 'City/Municipality',
                          child: _Box(
                            child: citiesAsync.when(
                              loading:
                                  () => const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: LinearProgressIndicator(
                                      minHeight: 2,
                                    ),
                                  ),
                              error:
                                  (e, _) => Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      'Failed to load cities:\n$e',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                              data: (cities) {
                                final items = <DropdownMenuItem<String?>>[
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('ALL'),
                                  ),
                                  ...cities.map(
                                    (c) => DropdownMenuItem<String?>(
                                      value: c.code,
                                      child: Text(
                                        c.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ];
                                return DropdownButtonFormField<String?>(
                                  value: _cityCode,
                                  isExpanded: true,
                                  items: items,
                                  onChanged:
                                      (code) =>
                                          setState(() => _cityCode = code),
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
                              if (picked != null)
                                setState(() => _range = picked);
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
                                      '${DateFormat('MM/dd/yy').format(_range.start)} - ${DateFormat('MM/dd/yy').format(_range.end)}',
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
                              loading:
                                  () => const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: LinearProgressIndicator(
                                      minHeight: 2,
                                    ),
                                  ),
                              error:
                                  (e, _) => Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      'Failed to load generics:\n$e',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
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
                              loading:
                                  () => const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: LinearProgressIndicator(
                                      minHeight: 2,
                                    ),
                                  ),
                              error:
                                  (e, _) => Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      'Failed to load brands:\n$e',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
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

                        // --------- Effects list (non-scrollable inside the ListView) ---------
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
                                return ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: list.length.clamp(0, 7),
                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, i) {
                                    final t = list[i];
                                    return _EffectTile(
                                      drug: t.drug.isEmpty ? 'Unknown' : t.drug,
                                      effect:
                                          t.effect.isEmpty
                                              ? 'Unspecified'
                                              : t.effect,
                                      cases: t.cases,
                                    );
                                  },
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
                          options: MapOptions(
                            initialCenter: _initialCenter,
                            initialZoom: _initialZoom,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.gamotph.app',
                            ),
                            trendsAsync.maybeWhen(
                              data:
                                  (res) => CircleLayer(
                                    circles: _buildHeatCircles(res.clusters),
                                  ),
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

  // --------------------------- heat helpers ---------------------------
  List<CircleMarker> _buildHeatCircles(List<TrendCluster> clusters) {
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
      final t = (c.count - minC) / denom;
      final color = _heatColor(t);
      final radiusMeters =
          (600 + 220 * math.sqrt(c.count)).clamp(400, 2500).toDouble();

      items.add(
        CircleMarker(
          point: c.center,
          useRadiusInMeter: true,
          radius: radiusMeters,
          color: color.withValues(alpha: 0.18),
          borderColor: color.withValues(alpha: 0.35),
          borderStrokeWidth: 1.2,
        ),
      );
    }
    return items;
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
  const _EffectTile({
    required this.drug,
    required this.effect,
    required this.cases,
  });
  final String drug;
  final String effect;
  final int cases;
  @override
  Widget build(BuildContext context) => Container(
    height: 70,
    decoration: BoxDecoration(
      color: const Color(0xFFF7F6FB),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE6E3EE)),
    ),
    child: Row(
      children: [
        const SizedBox(width: 10),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF233BCE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.event_note, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(drug, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(effect, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No. of Cases',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            Text(
              '$cases',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(width: 14),
      ],
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
