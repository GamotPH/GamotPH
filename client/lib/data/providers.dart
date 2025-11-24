// lib/data/providers.dart
import 'package:flutter/foundation.dart'; // @immutable
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

// Use LatLng from latlong2…
import 'package:latlong2/latlong.dart' show LatLng;
// …and LatLngBounds from flutter_map (NOT latlong2)
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;

import 'analytics_repository.dart';
import 'psgc_api.dart';

/* ------------------------------ Repositories ------------------------------ */

final repoProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepository(supa.Supabase.instance.client),
);

// FAMILY providers (important!)
final genericNameListProvider = FutureProvider.autoDispose
    .family<List<String>, String?>((ref, brandName) async {
      final repo = ref.read(repoProvider);
      final list = await repo.distinctGenericNames(
        brandName: (brandName == null || brandName == 'ALL') ? null : brandName,
      );
      return [
        'ALL',
        ...{...list},
      ];
    });

final brandNameListProvider = FutureProvider.autoDispose
    .family<List<String>, String?>((ref, genericName) async {
      final repo = ref.read(repoProvider);
      final list = await repo.distinctBrandNames(
        genericName:
            (genericName == null || genericName == 'ALL') ? null : genericName,
      );
      return [
        'ALL',
        ...{...list},
      ];
    });

/* ------------------------------ Global filters ---------------------------- */

final filterProvider = StateProvider<DashboardFilter>((ref) {
  final now = DateTime.now().toUtc();
  final start = DateTime.utc(now.year, 1, 1); // default: YTD
  return DashboardFilter(start: start, end: now.add(const Duration(days: 1)));
});

/* ------------------------------ UI state ---------------------------------- */

enum SymptomsGrouping { month, week }

final symptomsGroupingProvider = StateProvider<SymptomsGrouping>(
  (_) => SymptomsGrouping.month,
);

/* ------------------------------ Small DTOs -------------------------------- */

class ClinicalSeries {
  ClinicalSeries(this.labels, this.values);
  final List<String> labels;
  final List<double> values;
}

class PieSeries {
  final List<String> labels;
  final List<double> values;
  const PieSeries({required this.labels, required this.values});
}

/// Geo table model (matches rpc_geo_distribution -> geo_location, reports)
class GeoRow {
  final String location;
  final int reports;
  GeoRow({required this.location, required this.reports});
}

/* ------------------------------ Data providers ---------------------------- */

final keyMetricsProvider = FutureProvider.autoDispose((ref) async {
  final f = ref.watch(filterProvider);
  return ref.watch(repoProvider).keyMetrics(f);
});

final symptomsProvider = FutureProvider.autoDispose((ref) async {
  final f = ref.watch(filterProvider);
  return ref.watch(repoProvider).symptomsMonthly(f);
});

final wordCloudProvider = FutureProvider.autoDispose<List<WordItem>>((
  ref,
) async {
  final f = ref.watch(filterProvider);
  return ref.watch(repoProvider).wordCloud(f);
});

/// Geo Table (REAL DATA)
final geoDistributionProvider = FutureProvider.autoDispose<List<GeoRow>>((
  ref,
) async {
  final client = supa.Supabase.instance.client;
  final f = ref.watch(filterProvider);

  final result =
      await client
          .rpc(
            'rpc_geo_distribution',
            params: {
              'start_ts': f.start.toIso8601String(),
              'end_ts': f.end.toIso8601String(),
            },
          )
          .select(); // RPC returns SETOF rows

  String normalize(String? s) {
    if (s == null) return 'Unknown';
    final t = s.trim();
    if (t.isEmpty) return 'Unknown';
    if (t.toLowerCase().startsWith('failed to get address')) return 'Unknown';
    return t;
  }

  final List<dynamic> list = result as List<dynamic>;
  final rows =
      list
          .map((m) {
            final row = m as Map<String, dynamic>;
            return GeoRow(
              location: normalize(row['geo_location'] as String?),
              reports: (row['reports'] as num?)?.toInt() ?? 0,
            );
          })
          .where((r) => r.location != 'Unknown' && r.reports > 0)
          .toList()
        ..sort((a, b) => b.reports.compareTo(a.reports));

  return rows;
});

final topMedicineProvider = FutureProvider.autoDispose<(String?, int?)>((
  ref,
) async {
  final f = ref.watch(filterProvider);
  return ref.watch(repoProvider).topMedicine(f.start, f.end);
});

final clinicalManagementProvider = FutureProvider.autoDispose<ClinicalSeries>((
  ref,
) async {
  final f = ref.watch(filterProvider);
  final counts = await ref.watch(repoProvider).clinicalManagementCounts(f);

  const order = <String, String>{
    'dose_reduction': 'Dose Reduction',
    'drug_withdrawal': 'Drug Withdrawal',
    'hospitalization': 'Hospitalization',
    'stimulant_withdrawal': 'Stimulant Withdrawa',
    'psych_support': 'Psychological Support',
  };

  final labels = <String>[];
  final values = <double>[];

  for (final entry in order.entries) {
    labels.add(entry.value);
    values.add((counts[entry.key] ?? 0).toDouble());
  }

  int other = 0;
  for (final e in counts.entries) {
    if (!order.containsKey(e.key)) other += e.value;
  }
  if (other > 0) {
    labels.add('Other');
    values.add(other.toDouble());
  }

  return ClinicalSeries(labels, values);
});

final adverseReactionsProvider = FutureProvider.autoDispose<PieSeries>((
  ref,
) async {
  final f = ref.watch(filterProvider);
  final counts = await ref.watch(repoProvider).adverseReactionsCounts(f);

  final entries =
      counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  const topN = 5;
  final top = entries.take(topN).toList();
  final tail = entries.skip(topN);

  int otherSum = 0;
  for (final e in tail) {
    otherSum += e.value;
  }

  final labels = <String>[];
  final values = <double>[];

  for (final e in top) {
    labels.add(e.key);
    values.add(e.value.toDouble());
  }
  if (otherSum > 0) {
    labels.add('Other');
    values.add(otherSum.toDouble());
  }

  if (labels.isEmpty) {
    return const PieSeries(labels: [], values: []);
  }

  return PieSeries(labels: labels, values: values);
});

/* ------------------------------ PSGC-backed areas -------------------------- */

enum AreaLevel { region, province, city }

final areaLevelProvider = StateProvider<AreaLevel>((_) => AreaLevel.region);

// The currently-selected admin area (code). PSGC codes (9-digit strings).
final selectedAreaCodeProvider = StateProvider<String?>((_) => null);

// When level is province/city we need a parent (region or province PSGC code).
final parentAreaCodeProvider = StateProvider<String?>((_) => null);

// PSGC client
final psgcApiProvider = Provider<PsgcApi>((_) => PsgcApi());

// PSGC helpers
const kNcrRegionCode = '130000000'; // NCR in PSGC

// ✅ Correct PSGC patterns
// Regions: dd0000000  (e.g., 13 0000000)
bool _isRegionCode(String code) => RegExp(r'^\d{2}0{7}$').hasMatch(code);
// Provinces: ddd00000  (e.g., 041 00000 for Batangas)
bool _isProvinceCode(String code) =>
    !_isRegionCode(code) && RegExp(r'^\d{9}$').hasMatch(code);

// --- linked area selections (ALL == null) ---
final selectedRegionCodeProvider = StateProvider<String?>((_) => null);
final selectedProvinceCodeProvider = StateProvider<String?>((_) => null);
final selectedCityCodeProvider = StateProvider<String?>((_) => null);

/// Fetch areas list for the current level (and optional parent) via PSGC.
final adminAreasProvider = FutureProvider.autoDispose.family<
  List<AdminArea>,
  ({AreaLevel level, String? parentCode})
>((ref, args) async {
  final api = ref.watch(psgcApiProvider);

  switch (args.level) {
    case AreaLevel.region:
      {
        final items = await api.regions();
        return items
            .map((e) => AdminArea(code: e.code, name: e.name, level: 'region'))
            .toList();
      }

    case AreaLevel.province:
      {
        final region = args.parentCode;
        if (region == null) return const [];
        if (region == kNcrRegionCode) return const []; // NCR has no provinces
        final items = await api.provincesOfRegion(region);
        return items
            .map(
              (e) => AdminArea(
                code: e.code,
                name: e.name,
                level: 'province',
                parentCode: region,
              ),
            )
            .toList();
      }

    case AreaLevel.city:
      {
        final parent = args.parentCode;
        if (parent == null) return const [];

        // ✅ Province takes priority; otherwise region.
        final items =
            _isProvinceCode(parent)
                ? await api.citiesOfProvince(parent)
                : await api.citiesOfRegion(parent);

        return items
            .map(
              (e) => AdminArea(
                code: e.code,
                name: e.name,
                level: 'city',
                parentCode: parent,
              ),
            )
            .toList();
      }
  }
});

/// If/when you have polygons, return real bounds; for now keep a small fallback.
final selectedAdminBoundsProvider = FutureProvider.autoDispose<LatLngBounds?>((
  ref,
) async {
  final repo = ref.watch(repoProvider);
  final code = ref.watch(selectedAreaCodeProvider);
  if (code == null) return null;

  final bbox = await repo.adminBounds(code);
  if (bbox != null) return bbox;

  for (final entry in regionBounds.entries) {
    if (entry.key == 'NCR' && code == kNcrRegionCode) {
      return entry.value;
    }
  }
  return null;
});

/// Fallback simple region → bounding box map
final regionBounds = <String, LatLngBounds>{
  'NCR': LatLngBounds.fromPoints([
    const LatLng(14.35, 120.80), // SW
    const LatLng(14.90, 121.20), // NE
  ]),
  'Region III': LatLngBounds.fromPoints([
    const LatLng(14.60, 120.20),
    const LatLng(15.70, 121.70),
  ]),
  'Region IV-A': LatLngBounds.fromPoints([
    const LatLng(13.70, 120.50),
    const LatLng(14.60, 122.20),
  ]),
  'Region VII': LatLngBounds.fromPoints([
    const LatLng(9.40, 123.20),
    const LatLng(11.60, 125.00),
  ]),
};

@immutable
class TrendsParams {
  final String? areaCode; // PSGC code (region/province/city)
  final DateTime start;
  final DateTime end;
  final String? genericName;
  final String? brandName;

  const TrendsParams({
    required this.areaCode,
    required this.start,
    required this.end,
    this.genericName,
    this.brandName,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrendsParams &&
          other.areaCode == areaCode &&
          other.start == start &&
          other.end == end &&
          other.genericName == genericName &&
          other.brandName == brandName;

  @override
  int get hashCode => Object.hash(areaCode, start, end, brandName, genericName);

  @override
  String toString() =>
      'TrendsParams(areaCode: $areaCode, start: $start, end: $end, brandName: $brandName, genericName: $genericName)';
}

final trendsProvider = FutureProvider.autoDispose
    .family<TrendResult, TrendsParams>((ref, p) async {
      final repo = ref.read(repoProvider);

      // Reuse the shared bounds provider (it already calls repo.adminBounds
      // and has an NCR fallback). This also keeps things reactive.
      final bbox =
          (p.areaCode == null)
              ? null
              : await ref.read(selectedAdminBoundsProvider.future);

      return repo.fetchTrends(
        region: p.areaCode ?? 'ALL',
        start: p.start,
        end: p.end,
        brandName: p.brandName,
        genericName: p.genericName,
        bbox: bbox,
      );
    });

/* ------------------------------ Realtime invalidation --------------------- */

// lib/data/providers.dart

final metricsRealtimeProvider = Provider<void>((ref) {
  final client = supa.Supabase.instance.client;

  var isDisposed = false;
  ref.onDispose(() => isDisposed = true);

  void deferInvalidateAll() {
    // Run after the current build; bail out if provider got disposed.
    // wherever you do realtime -> invalidate:
    Future.microtask(() {
      ref.invalidate(keyMetricsProvider);
      ref.invalidate(symptomsProvider);
      ref.invalidate(wordCloudProvider);
      ref.invalidate(geoDistributionProvider);
      ref.invalidate(topMedicineProvider);
      ref.invalidate(clinicalManagementProvider);
      ref.invalidate(adverseReactionsProvider);
      ref.invalidate(trendsProvider);
    });
  }

  final channel =
      client
          .channel('public:adr_reports')
          .onPostgresChanges(
            event: supa.PostgresChangeEvent.insert,
            schema: 'public',
            table: 'adr_reports',
            callback: (_) => deferInvalidateAll(),
          )
          .onPostgresChanges(
            event: supa.PostgresChangeEvent.update,
            schema: 'public',
            table: 'adr_reports',
            callback: (_) => deferInvalidateAll(),
          )
          .onPostgresChanges(
            event: supa.PostgresChangeEvent.delete,
            schema: 'public',
            table: 'adr_reports',
            callback: (_) => deferInvalidateAll(),
          )
          .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
  });
});
