// lib/data/providers.dart
import 'dart:convert';

import 'package:flutter/foundation.dart'; // @immutable
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:http/http.dart' as http;

// Use LatLng from latlong2…
import 'package:latlong2/latlong.dart' show LatLng;
// …and LatLngBounds from flutter_map (NOT latlong2)
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;

import 'analytics_repository.dart';
import 'psgc_api.dart';
import 'backend_config.dart';
import 'top_adr.dart';
import 'adr_alias.dart';

/* ------------------------------ Repositories ------------------------------ */

final repoProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepository(supa.Supabase.instance.client),
);

final earliestReportDateProvider = FutureProvider<DateTime?>((ref) {
  return ref.watch(repoProvider).earliestReportDate();
});

/* ------------------------------ FAMILY providers -------------------------- */
final canonicalGenericMedicinesProvider = FutureProvider<List<String>>((
  ref,
) async {
  final res = await http.get(
    BackendConfig.uri('/api/v1/medicines/canonical-generics'),
  );

  if (res.statusCode != 200) {
    throw Exception('Failed to load medicines');
  }

  final decoded = jsonDecode(res.body);

  if (decoded is! List) {
    throw Exception('Invalid medicine response format');
  }

  return decoded.cast<String>();
});

final reportMedicineNamesProvider = FutureProvider<List<String>>((ref) async {
  final uri = BackendConfig.uri('/api/v1/analytics/medicine-names');
  final resp = await http.get(uri);

  if (resp.statusCode != 200) {
    throw Exception('Failed to load report medicines');
  }

  final decoded = jsonDecode(resp.body);
  final names = <String>{};
  if (decoded is List) {
    for (final item in decoded) {
      if (item is String && item.trim().isNotEmpty) {
        names.add(item.trim());
      }
    }
  }

  final list =
      names.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return ['All', ...list];
});

/* ------------------------------ Global filters ---------------------------- */

final filterProvider = StateProvider<DashboardFilter>((ref) {
  final now = DateTime.now();
  // All-time: start far in the past, end = tomorrow
  final start = DateTime(2000, 1, 1);
  final end = now.add(const Duration(days: 1));
  return DashboardFilter(start: start, end: end);
});

// ---------------------------
// Dashboard Filter Updater
// ---------------------------
/// The dashboard is always all-time; the only dynamic filter we apply
/// is by medicine.  Passing "All" or null clears the medicine filter.
void updateDashboardFilter(WidgetRef ref, {required String? medicine}) {
  final now = DateTime.now();
  final start = DateTime(2000, 1, 1);
  final end = now.add(const Duration(days: 1));

  String? normalizeAll(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    if (t.toLowerCase() == 'all') return null; // null = no filter
    return t;
  }

  ref.read(filterProvider.notifier).state = DashboardFilter(
    start: start,
    end: end,
    personId: null, // region / person filter removed
    medicine: normalizeAll(medicine),
  );
}

/* ------------------------------ UI state ---------------------------------- */

enum SymptomsGrouping { year, month }

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

  /// 👇 NEW: drilldown buckets
  final Map<String, Map<String, int>> breakdowns;

  const PieSeries({
    required this.labels,
    required this.values,
    this.breakdowns = const {},
  });
}

/// Geo table model (matches rpc_geo_distribution -> geo_location, reports)
class GeoRow {
  final String location;
  final int activeUsers; // distinct userID count
  final int reports;

  GeoRow({
    required this.location,
    required this.activeUsers,
    required this.reports,
  });
}

/// Report Logs
class ReportLogItem {
  final int id;
  final DateTime createdAt;
  final String location;
  final String medicineGeneric;
  final String medicineBrand;
  final String severity;
  final String reactionDescription;

  // New fields
  final String patientGender;
  final String patientAge;
  final String patientWeight;
  final String reasonForTaking;
  final String foodIntake;
  final String? drugImageUrl; // nullable – may not exist

  const ReportLogItem({
    required this.id,
    required this.createdAt,
    required this.location,
    required this.medicineGeneric,
    required this.medicineBrand,
    required this.severity,
    required this.reactionDescription,
    required this.patientGender,
    required this.patientAge,
    required this.patientWeight,
    required this.reasonForTaking,
    required this.foodIntake,
    required this.drugImageUrl,
  });

  String get displayMedicine {
    if (medicineGeneric.trim().isNotEmpty) return medicineGeneric.trim();
    if (medicineBrand.trim().isNotEmpty) return medicineBrand.trim();
    return 'Unknown medicine';
  }
}

/* ------------------------------ Data providers ---------------------------- */

// Key Metrics – return the KeyMetrics model from the repository
final keyMetricsProvider = FutureProvider<KeyMetrics>((ref) async {
  final repo = ref.watch(repoProvider); // <-- use repoProvider
  final filter = ref.watch(filterProvider); // <-- current dashboard filter
  return repo.keyMetrics(filter); // <-- returns KeyMetrics
});

final symptomsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final f = ref.watch(filterProvider);
  final repo = ref.watch(repoProvider);

  final results = await Future.wait([
    repo.symptomsMonthly(f),
    repo.symptomsYearly(f),
  ]);

  return {'monthly': results[0], 'yearly': results[1]};
});

final wordCloudProvider = FutureProvider<List<WordItem>>((ref) async {
  final f = ref.watch(filterProvider);
  return ref.watch(repoProvider).wordCloud(f);
});

/// Geo Table (REAL DATA)
final geoDistributionProvider = FutureProvider<List<GeoRow>>((ref) async {
  final client = supa.Supabase.instance.client;
  final f = ref.watch(filterProvider);

  // 1) Get base "reports per geoLocation" like before (RPC).
  final result =
      await client
          .rpc(
            'rpc_geo_distribution',
            params: {
              'start_ts': f.start.toIso8601String(),
              'end_ts': f.end.toIso8601String(),
            },
          )
          .select(); // returns [{ geo_location, reports }, ...]

  String normalize(String? s) {
    if (s == null) return 'Unknown';
    final t = s.trim();
    if (t.isEmpty) return 'Unknown';
    if (t.toLowerCase().startsWith('failed to get address')) return 'Unknown';
    return t;
  }

  final List<dynamic> list = result as List<dynamic>;

  // 2) Build a map of normalized location -> reports (from RPC)
  final Map<String, int> reportsByLoc = {};
  for (final m in list) {
    final row = m as Map<String, dynamic>;
    final loc = normalize(row['geo_location'] as String?);
    if (loc == 'Unknown') continue;
    final rep = (row['reports'] as num?)?.toInt() ?? 0;
    if (rep <= 0) continue;
    reportsByLoc[loc] = (reportsByLoc[loc] ?? 0) + rep;
  }

  if (reportsByLoc.isEmpty) return [];

  // 3) Get distinct userID per geoLocation from ADR_Reports.
  final adrRows = await client
      .from('ADR_Reports')
      .select('geoLocation, userID')
      .gte('created_at', f.start.toIso8601String())
      .lt('created_at', f.end.toIso8601String());

  final Map<String, Set<String>> usersByLoc = {};
  for (final row in adrRows as List<dynamic>) {
    final loc = normalize(row['geoLocation'] as String?);
    if (loc == 'Unknown') continue;
    final uid = (row['userID'] ?? '').toString().trim();
    if (uid.isEmpty) continue;

    usersByLoc.putIfAbsent(loc, () => <String>{}).add(uid);
  }

  // 4) Build final rows with activeUsers + reports.
  final rows = <GeoRow>[
    for (final entry in reportsByLoc.entries)
      GeoRow(
        location: entry.key,
        reports: entry.value,
        activeUsers: usersByLoc[entry.key]?.length ?? 0,
      ),
  ];

  // sort by reports desc
  rows.sort((a, b) => b.reports.compareTo(a.reports));
  return rows;
});

/// 🔹 Report logs (live ADR list, role-aware, no SQL join)
final reportLogsProvider = FutureProvider.autoDispose<List<ReportLogItem>>((
  ref,
) async {
  final client = supa.Supabase.instance.client;
  final f = ref.watch(filterProvider);

  final user = client.auth.currentUser;
  if (user == null) return const <ReportLogItem>[];

  // Assume role + pharmaco are stored in user metadata
  final meta = user.userMetadata ?? {};
  final role = (meta['role'] as String?)?.toLowerCase();
  final pharmacoId = meta['pharma_company_id'] ?? meta['pharmaco_id'];

  /* ───────── 1) Fetch ADR_Reports rows in time range ───────── */

  final rawAdrs =
      await client
              .from('ADR_Reports')
              .select('''
        reportID,
        created_at,
        geoLocation,
        reactionDescription,
        severity,
        userID,
        medicineId,
        patientGender,
        patientAge,
        patientWeight,
        reasonForTaking,
        foodIntake,
        drug_image_url
      ''')
              .gte('created_at', f.start.toIso8601String())
              .lt('created_at', f.end.toIso8601String())
          as List<dynamic>;

  if (rawAdrs.isEmpty) return const <ReportLogItem>[];

  bool isGarbageReaction(String raw) {
    final t = raw.trim().toLowerCase();

    if (t.isEmpty) return true;

    // obvious junk / placeholders
    const junk = {
      'unknown',
      'unspecified',
      'n/a',
      'na',
      'none',
      'nil',
      'test',
      'testing',
      'burger',
      'random',
      'sample',
    };
    if (junk.contains(t)) return true;

    // too short to be meaningful
    if (t.length < 4) return true;

    // no alphabetic characters at all
    if (!RegExp(r'[a-z]').hasMatch(t)) return true;

    // numbers only
    if (RegExp(r'^\d+$').hasMatch(t)) return true;

    return false;
  }

  /* ───────── 2) Collect medicineIds and fetch Medicines (no .in_()) ───────── */

  final Set<String> medIds = {};
  for (final row in rawAdrs) {
    final medIdRaw = row['medicineId'];
    if (medIdRaw == null) continue;
    medIds.add(medIdRaw.toString());
  }

  Map<String, Map<String, dynamic>> medsById = {};
  if (medIds.isNotEmpty) {
    // Table is small, so we can safely load all and map in Dart.
    final meds =
        await client
                .from('Medicines')
                .select('id, genericName, brandName, pharma_company_id')
            as List<dynamic>;

    medsById = {
      for (final m in meds)
        (m['id'] as int).toString(): m as Map<String, dynamic>,
    };
  }

  /* ───────── 3) Role-based filter ───────── */

  Iterable<dynamic> filteredAdrs = rawAdrs.where((row) {
    final raw = (row['reactionDescription'] ?? '').toString();
    return !isGarbageReaction(raw);
  });

  if (role == 'pharmaco' && pharmacoId != null) {
    // keep only ADRs whose medicine's pharmaco matches
    filteredAdrs = rawAdrs.where((row) {
      final medIdRaw = row['medicineId'];
      if (medIdRaw == null) return false;
      final med = medsById[medIdRaw.toString()];
      if (med == null) return false;
      final pc = med['pharma_company_id'];
      return pc != null && pc.toString() == pharmacoId.toString();
    });
  } else if (role == 'user') {
    // end users only see their own reports
    filteredAdrs = rawAdrs.where((row) {
      final uid = (row['userID'] ?? '').toString();
      return uid == user.id;
    });
  }
  // 'fda' or anything else → see everything

  String _clean(dynamic v) => (v ?? '').toString().trim();

  /* ───────── 4) Map to ReportLogItem and sort by date desc ───────── */

  final items =
      filteredAdrs.map<ReportLogItem>((row) {
        final medIdRaw = row['medicineId'];
        final med =
            medIdRaw == null
                ? null
                : medsById[medIdRaw.toString()]; // may be null

        final generic = (med?['genericName'] as String?)?.trim() ?? '';
        final brand = (med?['brandName'] as String?)?.trim() ?? '';

        final created =
            DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.now();

        final image = _clean(row['imageUrl']);

        return ReportLogItem(
          id: (row['reportID'] as num?)?.toInt() ?? 0,
          createdAt: created,
          location: _clean(row['geoLocation']),
          medicineGeneric: generic,
          medicineBrand: brand,
          severity: _clean(row['severity']),
          reactionDescription: _clean(row['reactionDescription']),
          patientGender: _clean(row['patientGender']), // 👈 from patientGender
          patientAge: _clean(row['patientAge']), // 👈 from patientAge
          patientWeight: _clean(row['patientWeight']), // 👈 from patientWeight
          reasonForTaking: _clean(row['reasonForTaking']),
          foodIntake: _clean(row['foodIntake']),
          drugImageUrl: image.isEmpty ? null : image,
        );
      }).toList();

  // Newest first
  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return items;
});

final topAdrsProvider = FutureProvider<List<TopAdr>>((ref) {
  final repo = ref.read(repoProvider);
  return repo.fetchTopAdrs(limit: 10);
});

/// 🔹 Top medicine by GENERIC NAME within the current filter's time range.
final topMedicineProvider = FutureProvider<(String?, int?)>((ref) async {
  final f = ref.watch(filterProvider);
  return ref.watch(repoProvider).topMedicine(f);
});

final clinicalManagementProvider = FutureProvider<ClinicalSeries>((ref) async {
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

/// 🔹 NEW: ADR pie data from backend-normalized reactions
final adverseReactionsProvider = FutureProvider<PieSeries>((ref) async {
  final f = ref.watch(filterProvider);
  final repo = ref.watch(repoProvider);

  // 1) Raw counts from Supabase
  final rawCounts = await repo.adverseReactionsCounts(f);
  if (rawCounts.isEmpty) {
    return const PieSeries(labels: [], values: [], breakdowns: {});
  }

  // 2) Payload for backend normalizer
  final payloadItems =
      rawCounts.entries.map((e) => {'text': e.key, 'count': e.value}).toList();

  final uri = Uri.parse(
    '${BackendConfig.baseUrl}/api/v1/analytics/normalize-reactions',
  );

  /// Canonical merged counts
  final Map<String, int> mergedCounts = {};

  /// 🔍 Drill-down buckets
  final Map<String, int> unmappedBreakdown = {};
  final Map<String, int> otherBreakdown = {};

  try {
    final resp = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'items': payloadItems}),
    );

    if (resp.statusCode == 200) {
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final items = (decoded['items'] as List<dynamic>? ?? []);

      for (final item in items) {
        final m = item as Map<String, dynamic>;
        final rawLabel = (m['label'] ?? '').toString().trim();
        final cnt = (m['count'] as num?)?.toInt() ?? 0;
        if (rawLabel.isEmpty || cnt <= 0) continue;

        final canonical = normalizeAdrAlias(rawLabel);

        mergedCounts[canonical] = (mergedCounts[canonical] ?? 0) + cnt;

        // Track unmapped raw terms
        if (canonical == 'Medical (Unmapped)') {
          unmappedBreakdown[rawLabel] =
              (unmappedBreakdown[rawLabel] ?? 0) + cnt;
        }
      }
    }
  } catch (_) {
    // swallow — fallback below
  }

  /// 🔁 HARD FALLBACK: alias-merge rawCounts
  if (mergedCounts.isEmpty) {
    rawCounts.forEach((label, count) {
      final canonical = normalizeAdrAlias(label);
      mergedCounts[canonical] = (mergedCounts[canonical] ?? 0) + count;

      if (canonical == 'Medical (Unmapped)') {
        unmappedBreakdown[label] = (unmappedBreakdown[label] ?? 0) + count;
      }
    });
  }

  if (mergedCounts.isEmpty) {
    return const PieSeries(labels: [], values: [], breakdowns: {});
  }

  // 3️⃣ Build pie using percentage cutoff (>= 3%)
  final total = mergedCounts.values.fold<int>(0, (a, b) => a + b);
  if (total == 0) {
    return const PieSeries(labels: [], values: [], breakdowns: {});
  }

  final entries =
      mergedCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  final labels = <String>[];
  final values = <double>[];
  int otherSum = 0;

  for (final e in entries) {
    final pct = e.value / total;

    if (pct >= 0.03) {
      labels.add(e.key);
      values.add(e.value.toDouble());
    } else {
      otherSum += e.value;
      otherBreakdown[e.key] = e.value;
    }
  }

  if (otherSum > 0) {
    labels.add('Other');
    values.add(otherSum.toDouble());
  }

  return PieSeries(
    labels: labels,
    values: values,
    breakdowns: {
      if (unmappedBreakdown.isNotEmpty) 'Medical (Unmapped)': unmappedBreakdown,
      if (otherBreakdown.isNotEmpty) 'Other': otherBreakdown,
    },
  );
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

final metricsRealtimeProvider = Provider<void>((ref) {
  final client = supa.Supabase.instance.client;

  var isDisposed = false;
  ref.onDispose(() => isDisposed = true);

  void deferInvalidateAll() {
    Future.microtask(() {
      if (isDisposed) return;
      ref.read(repoProvider).clearAnalyticsCache();
      ref.invalidate(keyMetricsProvider);
      ref.invalidate(symptomsProvider);
      ref.invalidate(wordCloudProvider);
      ref.invalidate(geoDistributionProvider);
      ref.invalidate(topMedicineProvider);
      ref.invalidate(clinicalManagementProvider);
      ref.invalidate(adverseReactionsProvider);
      ref.invalidate(trendsProvider);
      ref.invalidate(reportLogsProvider);
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
