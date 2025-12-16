// lib/data/analytics_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

// LatLng comes from latlong2…
import 'package:latlong2/latlong.dart' show LatLng;
// …but LatLngBounds is from flutter_map (NOT latlong2)
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'backend_config.dart';
import 'package:client/data/top_adr.dart';

/* ───────── Filters ───────── */

class DashboardFilter {
  final DateTime start;
  final DateTime end;
  final String? personId;
  final String? medicine;

  const DashboardFilter({
    required this.start,
    required this.end,
    this.personId,
    this.medicine,
  });
}

/* ───────── Models (existing) ───────── */

class KeyMetrics {
  final int activeUsers;
  final int reportedCases;
  final double validatedPct;
  KeyMetrics({
    required this.activeUsers,
    required this.reportedCases,
    required this.validatedPct,
  });
}

class SymptomPoint {
  final DateTime month; // start of bucket (month)
  final int total;
  SymptomPoint({required this.month, required this.total});
  DateTime get date => month;
  int get count => total;
  Map<String, dynamic> toJson() => {
    'date': month.toUtc().toIso8601String(),
    'count': total,
  };
}

class WordItem {
  final String text;
  final int weight;
  WordItem({required this.text, required this.weight});
}

class GeoRow {
  final String geoLocation;
  final int reports;
  GeoRow({required this.geoLocation, required this.reports});
}

class MonthlyCount {
  final DateTime month;
  final int count;
  MonthlyCount({required this.month, required this.count});
}

/* ───────── Models (for Trends Map) ───────── */

class TrendPoint {
  final double lat, lng;
  final String brandName; // e.g., Biogesic
  final String genericName; // e.g., Paracetamol
  final String sideEffect;
  TrendPoint({
    required this.lat,
    required this.lng,
    required this.brandName,
    required this.genericName,
    required this.sideEffect,
  });
}

class TrendCluster {
  final LatLng center;
  final int count;
  final String brandName; // used for legend/color
  final Map<String, int> effectCounts; // side-effect counts inside this cluster

  TrendCluster({
    required this.center,
    required this.count,
    required this.brandName,
    this.effectCounts = const {},
  });
}

class SideEffectCount {
  final String drug;
  final String effect;
  final int cases;
  SideEffectCount({
    required this.drug,
    required this.effect,
    required this.cases,
  });
}

class TrendResult {
  final List<TrendCluster> clusters;
  final List<SideEffectCount> topEffects;
  TrendResult({required this.clusters, required this.topEffects});
}

// --- Admin Areas (for Trends filters) ---
class AdminArea {
  final String code;
  final String name;
  final String level; // 'region' | 'province' | 'city'
  final String? parentCode; // null for regions
  final double? centroidLat;
  final double? centroidLng;

  const AdminArea({
    required this.code,
    required this.name,
    required this.level,
    this.parentCode,
    this.centroidLat,
    this.centroidLng,
  });
}

LatLngBounds? _bboxFromJson(Map<String, dynamic>? bbox) {
  if (bbox == null) return null;
  final w = (bbox['west'] as num?)?.toDouble();
  final e = (bbox['east'] as num?)?.toDouble();
  final s = (bbox['south'] as num?)?.toDouble();
  final n = (bbox['north'] as num?)?.toDouble();
  if (w != null && e != null && s != null && n != null) {
    return LatLngBounds(LatLng(s, w), LatLng(n, e));
  }
  return null;
}

/* ───────── Repository ───────── */

class AnalyticsRepository {
  final SupabaseClient sb;
  AnalyticsRepository(this.sb);

  static const _tblReports = 'ADR_Reports';
  static const _colCreatedAt = 'created_at';

  String _iso(DateTime dt) => dt.toUtc().toIso8601String();

  List _asList(dynamic res) {
    if (res == null) return const [];
    if (res is List) return res;
    if (res is Map<String, dynamic> && res['data'] is List) {
      return (res['data'] as List);
    }
    return const [];
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  /// Canonical form for medicine names:
  /// - lowercased
  /// - remove spaces and punctuation
  ///   e.g. "Alaxan Fr", "ALAXAN-FR", "AlaxanFr" -> "alaxanfr"
  String _canonDrugName(String? s) {
    if (s == null) return '';
    final t = s.trim().toLowerCase();
    if (t.isEmpty) return '';
    return t.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  /// Public wrapper so UI can canonicalize drug names the same way backend does.
  String canonDrug(String? s) => _canonDrugName(s);

  /// Normalize a drug name for dropdowns:
  /// - trims
  /// - removes weird punctuation
  /// - collapses spaces
  /// - Title Case (Paracetamol, Amoxicillin, Bioflu Forte)
  String _normalizeDrugName(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';

    // Remove non-alphanumeric characters (keep spaces)
    s = s.replaceAll(RegExp(r'[^A-Za-z0-9\s]'), ' ');
    // Collapse multiple spaces
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    s = s.toLowerCase();

    final parts = s.split(' ');
    final out = <String>[];
    for (final p in parts) {
      if (p.isEmpty) continue;
      out.add(p[0].toUpperCase() + p.substring(1));
    }
    return out.join(' ').trim();
  }

  /// Filter out junk values for brand / generic names
  bool _isJunkDrugName(String? value) {
    if (value == null) return true;
    final t = value.trim();
    if (t.isEmpty) return true;

    final lower = t.toLowerCase();

    // obvious junk / unknown markers
    if (lower == 'unknown' ||
        lower == 'n/a' ||
        lower == 'na' ||
        lower == 'none' ||
        lower == 'nil' ||
        lower == '-') {
      return true;
    }

    // very short things like "bb"
    if (lower.length < 3) return true;

    // purely numeric
    if (RegExp(r'^\d+$').hasMatch(lower)) return true;

    return false;
  }
  // ---------------------- NORMALIZATION HELPERS ----------------------

  String _canonDrug(String s) {
    return s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  bool _isJunkDrug(String s) {
    final lower = s.trim().toLowerCase();
    if (lower.isEmpty) return true;
    if (lower.length <= 2) return true; // removes "bb", "cc", etc.
    if (RegExp(r'^\d+$').hasMatch(lower)) return true; // numbers only
    if ([
      'unknown',
      'unspecified',
      'n/a',
      'na',
      'none',
      'nil',
      'empty',
      'other',
      'test',
    ].contains(lower))
      return true;

    return false;
  }

  String? _normalizeDrugDisplay(String? raw) {
    if (raw == null) return null;
    var t = raw.trim();
    if (_isJunkDrug(t)) return null;

    // Remove junk characters
    t = t.replaceAll(RegExp(r'[^A-Za-z0-9\s]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    if (t.trim().isEmpty) return null;

    // Title Case
    return t
        .split(' ')
        .map(
          (w) =>
              w.isEmpty
                  ? ''
                  : (w[0].toUpperCase() + w.substring(1).toLowerCase()),
        )
        .join(' ')
        .trim();
  }

  /* ───────── Medicines lookups (for dropdowns) ───────── */

  String? normalizeMedicineName(String? raw) {
    if (raw == null) return null;
    var t = raw.trim().toLowerCase();

    // junk filters
    if (t.isEmpty) return null;
    if (['unknown', 'n/a', 'na', 'none', 'nil', 'test', 'other'].contains(t)) {
      return null;
    }
    if (RegExp(r'^\d+$').hasMatch(t)) return null;
    if (t.length < 3) return null;

    // Remove non-letter characters but preserve spaces
    t = t.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ');

    // Title-case
    final words = t.split(' ').map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1);
    });

    final cleaned = words.join(' ').trim();
    if (cleaned.isEmpty) return null;

    return cleaned;
  }

  /// Canonical key used for dedupe
  String canonKey(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Distinct GENERIC names (from Medicines), optionally narrowed by brandName.
  /// - Trims whitespace
  /// - Filters junk like 'unknown', 'n/a', 'na'
  /// - Dedupes case-insensitively and ignoring spaces/punctuation
  // Future<List<String>> distinctGenericNames({String? brandName}) async {
  //   final rows = await sb.from('Medicines').select('genericName, brandName');

  //   final seen = <String>{};
  //   final out = <String>[];

  //   for (final m in rows) {
  //     final raw = m['genericName'] ?? '';
  //     final cleaned = normalizeMedicineName(raw);
  //     if (cleaned == null) continue;

  //     final key = canonKey(cleaned);
  //     if (seen.add(key)) out.add(cleaned);
  //   }

  //   out.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  //   return ['ALL', ...out];
  // }

  // Future<List<String>> distinctBrandNames({String? genericName}) async {
  //   final rows = await sb.from('Medicines').select('brandName, genericName');

  //   final seen = <String>{};
  //   final out = <String>[];

  //   for (final m in rows) {
  //     final raw = m['brandName'] ?? '';
  //     final cleaned = normalizeMedicineName(raw);
  //     if (cleaned == null) continue;

  //     final key = canonKey(cleaned);
  //     if (seen.add(key)) out.add(cleaned);
  //   }

  //   out.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  //   return ['ALL', ...out];
  // }

  Future<List<TopAdr>> fetchTopAdrs({int limit = 10}) async {
    final uri = BackendConfig.uri('/api/v1/analytics/top-adrs', {
      'limit': limit.toString(),
    });

    final resp = await http.get(uri);

    if (resp.statusCode != 200) {
      throw Exception('Failed to load top ADRs');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>;

    return items
        .map((e) => TopAdr.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /* ───────── INTERNAL: fetch all reports in batches (for key metrics) ───────── */

  /// Page through ALL matching ADR_Reports rows (ALL-TIME).
  /// - Ignores the date range so Key Metrics are ALL-TIME.
  /// - Still respects optional person + medicine filters.
  /// - Uses paging so we are not capped at 1000 rows.
  Future<List<Map<String, dynamic>>> _fetchReportsPaged(
    DashboardFilter f, {
    List<dynamic>? medIds,
  }) async {
    const batchSize = 1000; // Supabase limit per request
    int offset = 0;
    final List<Map<String, dynamic>> all = [];

    while (true) {
      // Base query (NO date filter → all-time)
      var q = sb
          .from('ADR_Reports')
          .select('reportID, userID, is_live, medicineId, created_at');

      // person filter
      final person = (f.personId ?? '').trim();
      if (person.isNotEmpty) {
        q = q.eq('userID', person);
      }

      // optional medicine filter
      if (medIds != null && medIds.isNotEmpty) {
        if (medIds.length == 1) {
          q = q.eq('medicineId', medIds.first);
        } else {
          final ors = medIds.map((id) => 'medicineId.eq.$id').join(',');
          q = q.or(ors);
        }
      }

      // IMPORTANT: order + range come *after* filters
      final rowsDynamic = await q
          .order('reportID', ascending: true) // stable ordering
          .range(offset, offset + batchSize - 1); // paging

      final rows =
          (rowsDynamic is List)
              ? rowsDynamic.cast<Map<String, dynamic>>()
              : <Map<String, dynamic>>[];

      if (rows.isEmpty) break;

      all.addAll(rows);

      // If less than a full page was returned, we've reached the end
      if (rows.length < batchSize) break;

      offset += batchSize;
    }

    return all;
  }

  /// Page through ALL ADR_Reports rows that we need for adverse reaction counts.
  Future<List<Map<String, dynamic>>> _fetchReactionRowsPaged(
    DashboardFilter f, {
    List<dynamic>? medIds,
  }) async {
    const batchSize = 1000; // Supabase per-request limit
    int offset = 0;
    final List<Map<String, dynamic>> all = [];

    while (true) {
      var q = sb
          .from(_tblReports)
          .select('created_at, userID, medicineId, reactionDescription')
          .gte('created_at', _iso(f.start))
          .lt('created_at', _iso(f.end));

      // Optional person filter
      final person = (f.personId ?? '').trim();
      if (person.isNotEmpty) {
        q = q.eq('userID', person);
      }

      // Optional medicine filter (avoid `.in_()`)
      if (medIds != null && medIds.isNotEmpty) {
        if (medIds.length == 1) {
          q = q.eq('medicineId', medIds.first);
        } else {
          final ors = medIds.map((id) => 'medicineId.eq.$id').join(',');
          q = q.or(ors);
        }
      }

      final rowsDynamic = await q
          .order('created_at', ascending: true)
          .range(offset, offset + batchSize - 1);

      final rows =
          (rowsDynamic is List)
              ? rowsDynamic.cast<Map<String, dynamic>>()
              : <Map<String, dynamic>>[];

      if (rows.isEmpty) break;

      all.addAll(rows);

      if (rows.length < batchSize) break; // last page
      offset += batchSize;
    }

    return all;
  }

  Future<int> fetchReportsCount(DashboardFilter f) async {
    final rows = await _fetchReportsPaged(f);
    return rows.length;
  }

  Future<int> fetchValidatedReportsCount(DashboardFilter f) async {
    final rows = await _fetchReportsPaged(f);

    int validated = 0;
    for (final r in rows) {
      final v = r['is_live'];
      final isValidated =
          (v is bool && v == true) ||
          (v is num && v != 0) ||
          (v is String && v.toLowerCase() == 'true');

      if (isValidated) {
        validated++;
      }
    }

    return validated;
  }

  Future<int> fetchActiveUsersCount(DashboardFilter f) async {
    final rows = await _fetchReportsPaged(f);

    final uniqueUsers = <String>{};

    for (final r in rows) {
      final id = (r['userID'] ?? '').toString().trim();
      if (id.isNotEmpty) uniqueUsers.add(id);
    }

    return uniqueUsers.length;
  }

  /* ───────── Key metrics, charts, word cloud, etc. ───────── */

  /// Key Metrics without RPC and without using `.in_()` (SDK-safe),
  /// now using paging so we see ALL matching reports, not just first 1000.
  Future<KeyMetrics> keyMetrics(DashboardFilter f) async {
    // 1) Resolve medicine text -> Medicine IDs (brandName or genericName ILIKE)
    List<dynamic>? medIds;

    final medRaw = f.medicine ?? '';
    final medNeedle = medRaw.trim();

    // 🔹 Treat null / empty / "all" as NO medicine filter
    if (medNeedle.isNotEmpty && medNeedle.toLowerCase() != 'all') {
      final meds = await sb
          .from('Medicines')
          .select('id, brandName, genericName')
          .or('brandName.ilike.%$medNeedle%,genericName.ilike.%$medNeedle%');

      final asList = (meds is List) ? meds : <dynamic>[];
      medIds =
          asList
              .map((e) => (e as Map<String, dynamic>)['id'])
              .where((id) => id != null)
              .toSet()
              .toList();

      // No matching medicines => 0 everywhere
      if (medIds.isEmpty) {
        return KeyMetrics(activeUsers: 0, reportedCases: 0, validatedPct: 0.0);
      }
    }

    // 2) Fetch *all* ADR_Reports rows for this filter (paged)
    final rows = await _fetchReportsPaged(f, medIds: medIds);

    if (rows.isEmpty) {
      return KeyMetrics(activeUsers: 0, reportedCases: 0, validatedPct: 0.0);
    }

    // reported_cases = total rows
    final total = rows.length;

    // active_users (distinct userID)
    final users = <String>{};
    for (final r in rows) {
      final uid = (r['userID'] ?? '').toString();
      if (uid.isNotEmpty) users.add(uid);
    }
    final activeUsers = users.length;

    // validated_pct (% with is_live truthy)
    int live = 0;
    for (final r in rows) {
      final v = r['is_live'];
      final isLive =
          (v is bool && v) ||
          (v is num && v != 0) ||
          (v is String && v.toLowerCase() == 'true');
      if (isLive) live++;
    }
    final validatedPct = (total == 0) ? 0.0 : (live * 100.0 / total);

    return KeyMetrics(
      activeUsers: activeUsers,
      reportedCases: total,
      validatedPct: validatedPct,
    );
  }

  // Compute symptoms activity MONTHLY over the whole date range
  Future<List<SymptomPoint>> symptomsMonthly(DashboardFilter f) async {
    // If a medicine text filter is provided, resolve it to matching Medicine IDs
    List<dynamic>? medIds;
    final medNeedle = (f.medicine ?? '').trim();
    if (medNeedle.isNotEmpty) {
      final meds = await sb
          .from('Medicines')
          .select('id, brandName, genericName')
          .or('brandName.ilike.%$medNeedle%,genericName.ilike.%$medNeedle%');

      final asList = (meds is List) ? meds : <dynamic>[];
      medIds =
          asList
              .map((e) => (e as Map<String, dynamic>)['id'])
              .where((id) => id != null)
              .toSet()
              .toList();

      // No matching medicine IDs ⇒ empty series
      if (medIds.isEmpty) {
        return const <SymptomPoint>[];
      }
    }

    // Base ADR_Reports query over the WHOLE filter range
    var q = sb
        .from('ADR_Reports')
        .select('created_at, userID, medicineId')
        .gte('created_at', _iso(f.start))
        .lt('created_at', _iso(f.end));

    // Optional person filter
    final person = (f.personId ?? '').trim();
    if (person.isNotEmpty) {
      q = q.eq('userID', person);
    }

    // Optional medicine filter (avoid .in_())
    if (medIds != null) {
      if (medIds.length == 1) {
        q = q.eq('medicineId', medIds.first);
      } else if (medIds.isNotEmpty) {
        final ors = medIds.map((id) => 'medicineId.eq.$id').join(',');
        q = q.or(ors);
      }
    }

    final rowsDynamic = await q;
    final rows =
        (rowsDynamic is List)
            ? rowsDynamic.cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[];

    // Count by month bucket (UTC)
    final byMonth = <DateTime, int>{};
    DateTime mStart(DateTime d) => DateTime.utc(d.year, d.month, 1);

    for (final r in rows) {
      final ts = r['created_at'];
      if (ts == null) continue;
      final dt = (ts is DateTime) ? ts.toUtc() : DateTime.parse('$ts').toUtc();
      final bucket = mStart(dt);
      byMonth.update(bucket, (v) => v + 1, ifAbsent: () => 1);
    }

    // Build all months from start..end (inclusive by month)
    DateTime cursor = mStart(f.start);
    final last = mStart(f.end);

    final out = <SymptomPoint>[];
    while (!cursor.isAfter(last)) {
      out.add(SymptomPoint(month: cursor, total: byMonth[cursor] ?? 0));
      cursor =
          (cursor.month == 12)
              ? DateTime.utc(cursor.year + 1, 1, 1)
              : DateTime.utc(cursor.year, cursor.month + 1, 1);
    }
    return out;
  }

  // Compute symptoms activity YEARLY over the whole date range
  Future<List<SymptomPoint>> symptomsYearly(DashboardFilter f) async {
    // Reuse the same filtering logic as monthly
    List<dynamic>? medIds;
    final medNeedle = (f.medicine ?? '').trim();
    if (medNeedle.isNotEmpty) {
      final meds = await sb
          .from('Medicines')
          .select('id, brandName, genericName')
          .or('brandName.ilike.%$medNeedle%,genericName.ilike.%$medNeedle%');

      final asList = (meds is List) ? meds : <dynamic>[];
      medIds =
          asList
              .map((e) => (e as Map<String, dynamic>)['id'])
              .where((id) => id != null)
              .toSet()
              .toList();

      if (medIds.isEmpty) {
        return const <SymptomPoint>[];
      }
    }

    var q = sb
        .from('ADR_Reports')
        .select('created_at, userID, medicineId')
        .gte('created_at', _iso(f.start))
        .lt('created_at', _iso(f.end));

    final person = (f.personId ?? '').trim();
    if (person.isNotEmpty) {
      q = q.eq('userID', person);
    }

    if (medIds != null) {
      if (medIds.length == 1) {
        q = q.eq('medicineId', medIds.first);
      } else if (medIds.isNotEmpty) {
        final ors = medIds.map((id) => 'medicineId.eq.$id').join(',');
        q = q.or(ors);
      }
    }

    final rowsDynamic = await q;
    final rows =
        (rowsDynamic is List)
            ? rowsDynamic.cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[];

    // Count per YEAR
    final byYear = <int, int>{};
    for (final r in rows) {
      final ts = r['created_at'];
      if (ts == null) continue;
      final dt = (ts is DateTime) ? ts.toUtc() : DateTime.parse('$ts').toUtc();
      final y = dt.year;
      byYear.update(y, (v) => v + 1, ifAbsent: () => 1);
    }

    final years = byYear.keys.toList()..sort();
    final out = <SymptomPoint>[];
    for (final y in years) {
      out.add(
        SymptomPoint(
          month: DateTime.utc(y, 1, 1), // use Jan 1 as "year label"
          total: byYear[y] ?? 0,
        ),
      );
    }
    return out;
  }
  /* ───────── Adverse Reactions: counts by reaction label (via backend NER+normalizer) ───────── */

  Future<Map<String, int>> adverseReactionsCounts(DashboardFilter f) async {
    // 1) Resolve medicine text filter -> Medicine IDs (same logic as symptoms/wordCloud)
    List<dynamic>? medIds;
    final medNeedle = (f.medicine ?? '').trim();

    if (medNeedle.isNotEmpty && medNeedle.toLowerCase() != 'all') {
      final meds = await sb
          .from('Medicines')
          .select('id, brandName, genericName')
          .or('brandName.ilike.%$medNeedle%,genericName.ilike.%$medNeedle%');

      final asList =
          (meds is List)
              ? meds.cast<Map<String, dynamic>>()
              : <Map<String, dynamic>>[];

      medIds =
          asList.map((e) => e['id']).where((id) => id != null).toSet().toList();

      // No match -> no reactions
      if (medIds.isEmpty) return const {};
    }

    // 2) Fetch ALL ADR_Reports rows in the time window (paged – no 1000-row cap)
    final rows = await _fetchReactionRowsPaged(f, medIds: medIds);
    if (rows.isEmpty) return const {};

    // 3) Local bucketing: raw text -> count (to reduce payload to backend)
    // For the pie we only care about reactionDescription (it is non-empty in 19k+ rows)
    const candidates = <String>['reactionDescription'];

    String? pick(Map<String, dynamic> m) {
      for (final k in candidates) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    String clean(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');
    String canon(String s) => clean(s).toLowerCase();

    bool isJunk(String s) {
      final v = s.trim().toLowerCase();
      return v.isEmpty ||
          v == 'reaction' ||
          v == 'unspecified' ||
          v == 'unknown' ||
          v == 'n/a' ||
          v == 'na';
    }

    final Map<String, int> rawCounts = {}; // key = canonical raw text
    final Map<String, String> displayFor = {}; // key -> pretty label

    for (final row in rows) {
      final raw = pick(row) ?? 'Unspecified';
      final label = isJunk(raw) ? 'Unspecified' : clean(raw);
      final key = canon(label);
      displayFor.putIfAbsent(key, () => label);
      rawCounts.update(key, (v) => v + 1, ifAbsent: () => 1);
    }

    if (rawCounts.isEmpty) return const {};

    // 4) Call backend NER + ADR normalizer to merge spellings & extract entities
    final uri = Uri.parse(
      '${BackendConfig.baseUrl}/api/v1/analytics/normalize-reactions',
    );

    final payloadItems =
        rawCounts.entries
            .map((e) => {'text': displayFor[e.key] ?? e.key, 'count': e.value})
            .toList();

    try {
      final resp = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'items': payloadItems}),
      );

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final List<dynamic> items = (decoded['items'] as List?) ?? const [];

        final Map<String, int> result = {};
        for (final item in items) {
          final m = item as Map<String, dynamic>;
          final label = (m['label'] ?? '').toString().trim();
          if (label.isEmpty) continue;
          final cnt = (m['count'] as num?)?.toInt() ?? 0;
          if (cnt <= 0) continue;
          result[label] = cnt;
        }

        // If backend returned something useful, use it
        if (result.isNotEmpty) return result;
      } else {
        // ignore: avoid_print
        print(
          'adverseReactionsCounts: backend returned ${resp.statusCode} ${resp.body}',
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('adverseReactionsCounts: backend call failed: $e');
    }

    // 5) Fallback: use local grouping (same behaviour as before, but no 1000-row cap)
    final Map<String, int> fallback = {};
    rawCounts.forEach((key, cnt) {
      fallback[displayFor[key] ?? key] = cnt;
    });
    return fallback;
  }

  /// Patient Experience word cloud
  ///
  /// Uses the SAME cleaned + normalized ADR labels as the
  /// Adverse Drug Reactions donut, by reusing [adverseReactionsCounts].
  /// - When f.medicine is null / "all" → all medicines
  /// - When f.medicine has a value     → only that medicine
  Future<List<WordItem>> wordCloud(DashboardFilter f, {int limit = 300}) async {
    // 1) Get normalized counts from the ADR normalizer pipeline
    final counts = await adverseReactionsCounts(f);

    if (counts.isEmpty) {
      return const <WordItem>[];
    }

    // 2) Sort by frequency (desc)
    final entries =
        counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // 3) Convert to WordItem list (top N), skipping junk like "Unspecified"
    final out = <WordItem>[];

    for (final e in entries) {
      final label = e.key.trim();
      final value = e.value;
      if (label.isEmpty || value <= 0) continue;

      final lower = label.toLowerCase();

      // ⛔ Do NOT show these in the WORD CLOUD (but they still exist in the donut)
      if (lower == 'unspecified' ||
          lower == 'unknown' ||
          lower == 'n/a' ||
          lower == 'na') {
        continue;
      }

      out.add(WordItem(text: label, weight: value));

      if (out.length >= limit) break; // only top N words in the cloud
    }

    return out;
  }

  Future<List<GeoRow>> geoTable(DashboardFilter f) async {
    final res = await sb.rpc(
      'rpc_geo_distribution',
      params: {'start_ts': _iso(f.start), 'end_ts': _iso(f.end)},
    );

    final list = _asList(res);
    return list
        .map((e) => e as Map<String, dynamic>)
        .map(
          (m) => GeoRow(
            geoLocation: (m['geo_location'] as String?) ?? 'Unknown',
            reports: _toInt(m['reports']),
          ),
        )
        .toList();
  }

  Future<List<MonthlyCount>> categoryTrend(
    DateTime start,
    DateTime end,
    String category,
  ) async {
    final res = await sb.rpc(
      'rpc_category_trend_monthly',
      params: {
        'start_ts': _iso(start),
        'end_ts': _iso(end),
        'category_name': category,
      },
    );

    final list = _asList(res);
    final out =
        list
            .map((e) => e as Map<String, dynamic>)
            .map(
              (m) => MonthlyCount(
                month:
                    (m['month'] is DateTime)
                        ? (m['month'] as DateTime).toUtc()
                        : DateTime.parse((m['month']).toString()).toUtc(),
                count: _toInt(m['cnt']),
              ),
            )
            .toList()
          ..sort((a, b) => a.month.compareTo(b.month));

    return out;
  }

  // Safely compute Top Medicine without RPCs or .in_()
  Future<(String?, int?)> topMedicine(DateTime start, DateTime end) async {
    // Pull only what we need from ADR_Reports
    final rowsDynamic = await sb
        .from('ADR_Reports')
        .select('medicineId, created_at')
        .gte('created_at', _iso(start))
        .lt('created_at', _iso(end));

    final rows =
        (rowsDynamic is List)
            ? rowsDynamic.cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[];

    if (rows.isEmpty) return (null, null);

    // Count by medicineId (client-side)
    final countsById = <dynamic, int>{};
    for (final r in rows) {
      final id = r['medicineId'];
      if (id == null) continue;
      countsById.update(id, (v) => v + 1, ifAbsent: () => 1);
    }
    if (countsById.isEmpty) return (null, null);

    // Pick top medicineId
    dynamic topId;
    int topCount = 0;
    countsById.forEach((id, cnt) {
      if (cnt > topCount) {
        topId = id;
        topCount = cnt;
      }
    });

    // Resolve display name from Medicines
    String? name;
    if (topId != null) {
      final medRes = await sb
          .from('Medicines')
          .select('brandName, genericName')
          .eq('id', topId)
          .limit(1);

      final med =
          (medRes is List && medRes.isNotEmpty)
              ? (medRes.first as Map<String, dynamic>)
              : null;
      final brand = (med?['brandName'] as String?)?.trim();
      final generic = (med?['genericName'] as String?)?.trim();
      name =
          (brand?.isNotEmpty ?? false)
              ? brand
              : (generic?.isNotEmpty ?? false)
              ? generic
              : 'Unknown';
    }

    return (name, topCount);
  }

  /* ───────── Clinical Management: counts by type ───────── */

  Future<Map<String, int>> clinicalManagementCounts(DashboardFilter f) async {
    var q = sb
        .from(_tblReports)
        .select('$_colCreatedAt, actionTakenWithMedicine, reactionOutcome')
        .gte(_colCreatedAt, _iso(f.start))
        .lte(_colCreatedAt, _iso(f.end));

    final List rows = await q;
    if (rows.isEmpty) {
      // ignore: avoid_print
      print('CM: 0 rows for ${f.start}..${f.end}');
      return const {};
    }

    String bucketFor(String? s) {
      final t = (s ?? '').toLowerCase();
      if (RegExp(
        r'\b(stop|stopp(ed|ing)?|discontinu(e|ed|ation)|cease|withdraw(al)?|withdrew)\b',
      ).hasMatch(t)) {
        return 'drug_withdrawal';
      }
      if (RegExp(
        r'\b(reduc(e|ed|ing)|lower(ed|ing)?\s+dose|taper(ing)?)\b',
      ).hasMatch(t)) {
        return 'dose_reduction';
      }
      if (RegExp(
        r'\b(hospitali[sz]e(d)?|admit(ted)?|er|emergency|icu)\b',
      ).hasMatch(t)) {
        return 'hospitalization';
      }
      if (RegExp(
        r'\b(psych(ological)?\s*support|counsel(ing)?|advice|reassurance)\b',
      ).hasMatch(t)) {
        return 'psych_support';
      }
      if (RegExp(r'\bstimulant(s)?\s+withdraw(al)?\b').hasMatch(t)) {
        return 'stimulant_withdrawal';
      }
      return 'other';
    }

    final Map<String, int> counts = {};
    for (final r in rows.cast<Map<String, dynamic>>()) {
      final act = r['actionTakenWithMedicine'] as String?;
      final outc = r['reactionOutcome'] as String?;
      final k = bucketFor((act?.trim().isNotEmpty ?? false) ? act : outc);
      counts.update(k, (v) => v + 1, ifAbsent: () => 1);
    }

    // ignore: avoid_print
    print(
      'CM: derived from actionTakenWithMedicine/reactionOutcome -> $counts rows=${rows.length}',
    );
    return counts;
  }

  /* ───────── Admin Areas / Bounds ───────── */

  Future<List<AdminArea>> adminAreas({
    required String level, // 'region' | 'province' | 'city'
    String? parentCode, // e.g. region code when level='province'
  }) async {
    final res = await sb.rpc(
      'rpc_admin_areas',
      params: {'p_level': level, 'p_parent_code': parentCode},
    );

    List list;
    if (res is List) {
      list = res;
    } else if (res is Map<String, dynamic> && res['data'] is List) {
      list = res['data'] as List;
    } else {
      list = const [];
    }

    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return AdminArea(
        code: (m['code'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        level: (m['level'] ?? '').toString(),
        parentCode: (m['parent_code'] as String?),
        centroidLat:
            (m['centroid_lat'] is num)
                ? (m['centroid_lat'] as num).toDouble()
                : null,
        centroidLng:
            (m['centroid_lng'] is num)
                ? (m['centroid_lng'] as num).toDouble()
                : null,
      );
    }).toList();
  }

  /// Cities/Municipalities helper that always uses the right parent.
  ///
  /// - If [provinceCode] is provided, fetch cities under that province.
  /// - Else if [regionCode] is provided, fetch cities under that region.
  /// - Else (both null), fetch ALL cities.
  Future<List<AdminArea>> citiesByParent({
    String? regionCode,
    String? provinceCode,
  }) {
    // Province takes priority when both are present
    final parent = provinceCode ?? regionCode;
    return adminAreas(level: 'city', parentCode: parent);
  }

  Future<LatLngBounds?> adminBounds(String code) async {
    final res = await sb.rpc('rpc_admin_bbox', params: {'p_code': code});

    Map<String, dynamic>? payload;

    // Case 1: raw object  -> { west, east, south, north }
    if (res is Map<String, dynamic> && res.containsKey('west')) {
      payload = res;
    }
    // Case 2: wrapped as { data: { ... } }
    else if (res is Map<String, dynamic> &&
        res['data'] is Map<String, dynamic>) {
      final m = res['data'] as Map<String, dynamic>;
      if (m.containsKey('west')) payload = m;
    }
    // Case 3: SETOF/array [ { ... } ]
    else if (res is List &&
        res.isNotEmpty &&
        res.first is Map<String, dynamic>) {
      final m = res.first as Map<String, dynamic>;
      if (m.containsKey('west')) payload = m;
    }

    if (payload == null) return null;
    return _bboxFromJson(payload);
  }

  /* ───────── Trends Map: clusters + top side effects ───────── */

  Future<TrendResult> fetchTrends({
    required String region, // unused for now
    required DateTime start,
    required DateTime end,
    String? brandName,
    String? genericName,
    LatLngBounds? bbox,
    int hardLimit = 5000,
  }) async {
    // Canonical filter values (match dropdown normalization)
    final canonFilterBrand = _canonDrugName(brandName);
    final canonFilterGeneric = _canonDrugName(genericName);
    // Only select columns that exist on your table
    final res = await sb
        .from(_tblReports)
        .select('$_colCreatedAt, medicineId, reactionDescription, latlng')
        .gte(_colCreatedAt, _iso(start))
        .lt(_colCreatedAt, _iso(end))
        .limit(hardLimit);

    final rows =
        (res is List)
            ? res.cast<Map<String, dynamic>>()
            : const <Map<String, dynamic>>[];

    if (rows.isEmpty) {
      return TrendResult(clusters: const [], topEffects: const []);
    }

    // Resolve medicineId → names (no `.in_()`)
    final medIds = <dynamic>{};
    for (final r in rows) {
      final id = r['medicineId'];
      if (id != null) medIds.add(id);
    }

    final medMap = <dynamic, Map<String, String>>{};
    if (medIds.isNotEmpty) {
      final ors = medIds.map((id) => 'id.eq.$id').join(',');
      final medsRes = await sb
          .from('Medicines')
          .select('id, brandName, genericName')
          .or(ors);

      final meds =
          (medsRes is List)
              ? medsRes.cast<Map<String, dynamic>>()
              : const <Map<String, dynamic>>[];
      for (final m in meds) {
        final id = m['id'];
        medMap[id] = {
          'brand': ((m['brandName'] as String?) ?? '').trim(),
          'generic': ((m['genericName'] as String?) ?? '').trim(),
        };
      }
    }

    // Helpers
    String _clean(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');
    String _canon(String s) => _clean(s).toLowerCase();
    bool _junk(String s) {
      final v = s.trim().toLowerCase();
      return v.isEmpty ||
          v == 'reaction' ||
          v == 'unspecified' ||
          v == 'unknown' ||
          v == 'n/a' ||
          v == 'na' ||
          v == 'empty';
    }

    // Parse "lat, lng" from text field
    (double? lat, double? lng) _parseLatLng(dynamic v) {
      if (v is! String) return (null, null);
      final s = v.trim();
      if (s.isEmpty || s.toLowerCase() == 'empty') return (null, null);
      final m = RegExp(
        r'(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)',
      ).firstMatch(s);
      if (m == null) return (null, null);
      final lat = double.tryParse(m.group(1)!);
      final lng = double.tryParse(m.group(2)!);
      return (lat, lng);
    }

    // Build clusters + top effects
    final pts = <TrendPoint>[];

    final counts = <String, int>{}; // "$drugKey|||$effKey" -> cases
    final displayDrug = <String, String>{}; // canonical -> display label
    final displayEff = <String, String>{}; // canonical -> display label

    for (final r in rows) {
      final names =
          medMap[r['medicineId']] ?? const {'brand': '', 'generic': ''};
      final brand = names['brand'] ?? '';
      final generic = names['generic'] ?? '';

      final brandKey = _canonDrugName(brand);
      final genericKey = _canonDrugName(generic);

      // Apply normalized filters (exact match on canonical form)
      if (canonFilterBrand.isNotEmpty && brandKey != canonFilterBrand) {
        continue;
      }
      if (canonFilterGeneric.isNotEmpty && genericKey != canonFilterGeneric) {
        continue;
      }

      final drugDisplay =
          brand.isNotEmpty ? brand : (generic.isNotEmpty ? generic : 'Unknown');
      final drugKey = _canon(drugDisplay);

      // Parse coordinates from latlng
      final (lat, lng) = _parseLatLng(r['latlng']);

      // Filter by selected region/province/city bounds (use contains for safety)
      if (bbox != null) {
        if (lat == null || lng == null) continue;
        final inside = bbox.contains(LatLng(lat, lng));
        if (!inside) continue;
      }

      // Reaction description
      final raw = (r['reactionDescription'] as String?) ?? 'Unspecified';
      final effDisplay = _junk(raw) ? 'Unspecified' : _clean(raw);
      final effKey = _canon(effDisplay);

      // Count side effects (already area-filtered)
      final pairKey = '$drugKey|||$effKey';
      displayDrug.putIfAbsent(drugKey, () => drugDisplay);
      displayEff.putIfAbsent(effKey, () => effDisplay);
      counts.update(pairKey, (v) => v + 1, ifAbsent: () => 1);

      // For map clustering
      if (lat != null && lng != null) {
        pts.add(
          TrendPoint(
            lat: lat,
            lng: lng,
            brandName: brand,
            genericName: generic,
            sideEffect: effDisplay,
          ),
        );
      }
    }

    // Grid clustering (~5–6km)
    final clusters = <TrendCluster>[];
    if (pts.isNotEmpty) {
      const bucketDeg = 0.05;
      final buckets = <String, List<TrendPoint>>{};

      for (final p in pts) {
        final key =
            '${(p.lat / bucketDeg).floor()}_${(p.lng / bucketDeg).floor()}';
        (buckets[key] ??= <TrendPoint>[]).add(p);
      }

      buckets.forEach((_, list) {
        final lat = list.fold<double>(0, (a, b) => a + b.lat) / list.length;
        final lng = list.fold<double>(0, (a, b) => a + b.lng) / list.length;
        final brand =
            list.first.brandName.isEmpty ? 'other' : list.first.brandName;

        // Aggregate side effects inside this cluster
        final Map<String, int> effCounts = {};
        for (final p in list) {
          final eff = p.sideEffect.trim();
          if (eff.isEmpty) continue;
          final key = eff.toLowerCase();
          effCounts.update(key, (v) => v + 1, ifAbsent: () => 1);
        }

        clusters.add(
          TrendCluster(
            center: LatLng(lat, lng),
            count: list.length,
            brandName: brand,
            effectCounts: effCounts,
          ),
        );
      });
    }

    // Rank top effects (UI shows up to 7)
    final entries =
        counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final topEffects = <SideEffectCount>[];
    for (final e in entries.take(50)) {
      final parts = e.key.split('|||');
      final drug = displayDrug[parts[0]] ?? 'Unknown';
      final eff = displayEff[parts[1]] ?? 'Unspecified';

      final drugKey = drug.toLowerCase();
      final effKey = eff.toLowerCase();

      // Skip junk / unknown entries in the "Top side effects" list
      if (drugKey == 'unknown') continue;
      if (effKey == 'unknown' || effKey == 'unspecified') continue;

      topEffects.add(SideEffectCount(drug: drug, effect: eff, cases: e.value));
    }

    return TrendResult(clusters: clusters, topEffects: topEffects);
  }
}
