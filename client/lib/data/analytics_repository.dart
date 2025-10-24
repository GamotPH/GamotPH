// lib/data/analytics_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

// LatLng comes from latlong2…
import 'package:latlong2/latlong.dart' show LatLng;
// …but LatLngBounds is from flutter_map (NOT latlong2)
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;

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

class TopAdr {
  final String category;
  final int count;
  TopAdr({required this.category, required this.count});
}

class MonthlyCount {
  final DateTime month;
  final int count;
  MonthlyCount({required this.month, required this.count});
}

/* ───────── Models (NEW for Trends Map) ───────── */

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
  TrendCluster({
    required this.center,
    required this.count,
    required this.brandName,
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
  static const _colPersonId = 'person_id';
  static const _colDrugName = 'drug_name';

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

  double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  /* ───────── NEW: Medicines lookups (for dropdowns) ───────── */

  /// Distinct GENERIC names (from Medicines), optionally narrowed by brandName
  Future<List<String>> distinctGenericNames({String? brandName}) async {
    final needle = (brandName ?? '').trim();
    var q = sb.from('Medicines').select('genericName, brandName');

    if (needle.isNotEmpty && needle.toLowerCase() != 'all') {
      // case-insensitive partial match against brand
      q = q.ilike('brandName', '%$needle%');
    }

    final res = await q.limit(20000);
    final rows =
        (res is List)
            ? res.cast<Map<String, dynamic>>()
            : const <Map<String, dynamic>>[];

    final set = <String>{};
    for (final m in rows) {
      final g = (m['genericName'] as String?)?.trim();
      if (g != null && g.isNotEmpty) set.add(g);
    }
    final list =
        set.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  /// Distinct BRAND names (from Medicines), optionally narrowed by genericName
  Future<List<String>> distinctBrandNames({String? genericName}) async {
    final needle = (genericName ?? '').trim();
    var q = sb.from('Medicines').select('brandName, genericName');

    if (needle.isNotEmpty && needle.toLowerCase() != 'all') {
      // case-insensitive partial match against generic
      q = q.ilike('genericName', '%$needle%');
    }

    final res = await q.limit(20000);
    final rows =
        (res is List)
            ? res.cast<Map<String, dynamic>>()
            : const <Map<String, dynamic>>[];

    final set = <String>{};
    for (final m in rows) {
      final b = (m['brandName'] as String?)?.trim();
      if (b != null && b.isNotEmpty) set.add(b);
    }
    final list =
        set.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  /* ───────── Key metrics, charts, word cloud, etc. (existing) ───────── */

  /// Key Metrics without RPC and without using `.in_()` (SDK-safe)
  Future<KeyMetrics> keyMetrics(DashboardFilter f) async {
    // 1) Resolve medicine text -> Medicine IDs (brandName or genericName ILIKE)
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
              .toSet() // dedupe
              .toList();

      if (medIds.isEmpty) {
        return KeyMetrics(activeUsers: 0, reportedCases: 0, validatedPct: 0.0);
      }
    }

    // 2) Base ADR_Reports query for date window
    var q = sb
        .from('ADR_Reports')
        .select('userID, is_live, medicineId, created_at')
        .gte('created_at', _iso(f.start))
        .lt('created_at', _iso(f.end));

    // Optional person filter
    final person = (f.personId ?? '').trim();
    if (person.isNotEmpty) {
      q = q.eq('userID', person);
    }

    // Optional medicine filter WITHOUT `.in_()`
    if (medIds != null) {
      if (medIds.length == 1) {
        q = q.eq('medicineId', medIds.first);
      } else {
        // Build `or()` expression: medicineId.eq.id1,medicineId.eq.id2,...
        final ors = medIds.map((id) => 'medicineId.eq.$id').join(',');
        q = q.or(ors);
      }
    }

    // 3) Fetch & aggregate
    final rowsDynamic = await q;
    final rows =
        (rowsDynamic is List)
            ? rowsDynamic.cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[];

    if (rows.isEmpty) {
      return KeyMetrics(activeUsers: 0, reportedCases: 0, validatedPct: 0.0);
    }

    // reported_cases
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

  // Compute monthly symptoms activity WITHOUT RPCs (SDK-safe, no .in_())
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

      // No matching medicine IDs ⇒ empty series, still return filled months
      if (medIds.isEmpty) {
        return _fillLast12Months(f.start, f.end, const <DateTime, int>{});
      }
    }

    // Base ADR_Reports query
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

    // Optional medicine filter (avoid .in_() for SDK compatibility)
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
    DateTime monthStart(DateTime d) => DateTime.utc(d.year, d.month, 1);

    for (final r in rows) {
      final ts = r['created_at'];
      if (ts == null) continue;
      final dt = (ts is DateTime) ? ts.toUtc() : DateTime.parse('$ts').toUtc();
      final bucket = monthStart(dt);
      byMonth.update(bucket, (v) => v + 1, ifAbsent: () => 1);
    }

    // Return last 12 months (like your previous logic), filled with zeros
    return _fillLast12Months(f.start, f.end, byMonth);
  }

  // --- helper to fill a continuous 12-month window ending at f.end ---
  List<SymptomPoint> _fillLast12Months(
    DateTime start,
    DateTime end,
    Map<DateTime, int> byMonth,
  ) {
    DateTime mStart(DateTime d) => DateTime.utc(d.year, d.month, 1);
    var s = mStart(start);
    final e = mStart(end);
    final minStart = DateTime.utc(e.year, e.month - 11, 1);
    if (s.isBefore(minStart)) s = minStart;

    final out = <SymptomPoint>[];
    var cursor = s;
    while (!cursor.isAfter(e)) {
      out.add(SymptomPoint(month: cursor, total: byMonth[cursor] ?? 0));
      cursor =
          (cursor.month == 12)
              ? DateTime.utc(cursor.year + 1, 1, 1)
              : DateTime.utc(cursor.year, cursor.month + 1, 1);
    }
    return out;
  }

  /// Build a word cloud client-side (no RPC; no legacy column names).
  /// - Respects date range + optional person/medicine text filter.
  /// - Uses common reaction columns and collapses noisy labels.
  Future<List<WordItem>> wordCloud(DashboardFilter f, {int limit = 100}) async {
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

      // No match -> return empty cloud fast
      if (medIds.isEmpty) return const <WordItem>[];
    }

    // Base ADR_Reports query in date window
    var q = sb
        .from('ADR_Reports')
        .select('$_colCreatedAt, *')
        .gte(_colCreatedAt, _iso(f.start))
        .lt(_colCreatedAt, _iso(f.end));

    // Optional person filter (matches your ADR_Reports userID/person column)
    final person = (f.personId ?? '').trim();
    if (person.isNotEmpty) {
      // If your column is not userID, change here.
      q = q.eq('userID', person);
    }

    // Optional medicine filter against resolved IDs (avoids `.in_()`)
    if (medIds != null) {
      if (medIds.length == 1) {
        q = q.eq('medicineId', medIds.first);
      } else if (medIds.isNotEmpty) {
        final ors = medIds.map((id) => 'medicineId.eq.$id').join(',');
        q = q.or(ors);
      }
    }

    // Fetch
    final rowsDynamic = await q;
    final rows =
        (rowsDynamic is List)
            ? rowsDynamic.cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[];

    if (rows.isEmpty) return const <WordItem>[];

    // Reaction field candidates we’ll sniff (same set you already use elsewhere)
    const candidates = <String>[
      'reactionDescription',
      'reaction_pt',
      'reaction',
      'adr_category',
      'adverse_reaction',
      'adverseReaction',
      'reactionTerm',
      'reportedReaction',
      'reaction_label',
    ];

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

    // Aggregate counts
    final grouped = <String, int>{}; // canonical -> count
    final displayFor = <String, String>{}; // canonical -> display label

    for (final m in rows) {
      final raw = pick(m) ?? 'Unspecified';
      final label = isJunk(raw) ? 'Unspecified' : clean(raw);
      final key = canon(label);
      displayFor.putIfAbsent(key, () => label);
      grouped.update(key, (v) => v + 1, ifAbsent: () => 1);
    }

    // Sort desc, take top N, map to WordItem
    final entries =
        grouped.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final out = <WordItem>[];
    for (final e in entries.take(limit)) {
      final label = displayFor[e.key] ?? 'Unspecified';
      out.add(WordItem(text: label, weight: e.value));
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

  Future<List<TopAdr>> topAdr(
    DateTime start,
    DateTime end, {
    int limit = 10,
  }) async {
    final res = await sb.rpc(
      'rpc_top_adr_categories',
      params: {'start_ts': _iso(start), 'end_ts': _iso(end), 'limit_n': limit},
    );

    final list = _asList(res);
    return list
        .map((e) => e as Map<String, dynamic>)
        .map(
          (m) => TopAdr(
            category: (m['category'] ?? '').toString(),
            count: _toInt(m['cnt']),
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

    if ((f.personId ?? '').isNotEmpty && _colPersonId.isNotEmpty) {
      q = q.eq(_colPersonId, f.personId!);
    }
    if ((f.medicine ?? '').isNotEmpty && _colDrugName.isNotEmpty) {
      q = q.eq(_colDrugName, f.medicine!);
    }

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

  /* ───────── Adverse Reactions: counts by reaction label ───────── */

  Future<Map<String, int>> adverseReactionsCounts(DashboardFilter f) async {
    var q = sb
        .from(_tblReports)
        .select('$_colCreatedAt, *')
        .gte(_colCreatedAt, _iso(f.start))
        .lt(_colCreatedAt, _iso(f.end));

    if ((f.personId ?? '').isNotEmpty && _colPersonId.isNotEmpty) {
      q = q.eq(_colPersonId, f.personId!);
    }
    if ((f.medicine ?? '').isNotEmpty && _colDrugName.isNotEmpty) {
      q = q.eq(_colDrugName, f.medicine!);
    }

    final List rows = await q;
    if (rows.isEmpty) return const {};

    const candidates = <String>[
      'reactionDescription',
      'reaction_pt',
      'reaction',
      'adr_category',
      'adverse_reaction',
      'adverseReaction',
      'reactionTerm',
      'reportedReaction',
      'reaction_label',
    ];

    String? _pick(Map<String, dynamic> m) {
      for (final k in candidates) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v;
      }
      return null;
    }

    String _clean(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');
    String _canon(String s) => _clean(s).toLowerCase();

    bool _isJunk(String s) {
      final v = s.trim().toLowerCase();
      return v.isEmpty ||
          v == 'reaction' ||
          v == 'unspecified' ||
          v == 'unknown' ||
          v == 'n/a' ||
          v == 'na';
    }

    final Map<String, int> grouped = {};
    final Map<String, String> displayFor = {};

    for (final row in rows.cast<Map<String, dynamic>>()) {
      final raw = _pick(row) ?? 'Unspecified';
      final label = _isJunk(raw) ? 'Unspecified' : _clean(raw);
      final key = _canon(label);
      displayFor.putIfAbsent(key, () => label);
      grouped.update(key, (v) => v + 1, ifAbsent: () => 1);
    }

    final Map<String, int> out = {};
    for (final e in grouped.entries) {
      out[displayFor[e.key] ?? 'Unspecified'] = e.value;
    }
    return out;
  }

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

  // (paste INSIDE class AnalyticsRepository, right after adminAreas())

  /// Cities/Municipalities helper that always uses the right parent.
  ///
  /// - If [provinceCode] is provided, fetch cities under that province.
  /// - Else if [regionCode] is provided, fetch cities under that region.
  /// - Else (both null), fetch ALL cities.
  ///
  /// This keeps callers simple and avoids mixing up parent scopes.
  Future<List<AdminArea>> citiesByParent({
    String? regionCode,
    String? provinceCode,
  }) {
    // Province takes priority when both are present
    final parent = provinceCode ?? regionCode;
    return adminAreas(level: 'city', parentCode: parent);
  }

  Future<LatLngBounds?> adminBounds(String code) async {
    // Expects rpc_admin_bbox(code) -> {west,east,south,north}
    final res = await sb.rpc('rpc_admin_bbox', params: {'p_code': code});
    if (res is Map<String, dynamic>) {
      return _bboxFromJson(res);
    }
    return null;
  }

  /* ───────── Trends Map: clusters + top side effects ───────── */

  Future<TrendResult> fetchTrends({
    required String region, // currently unused; left for future bbox join
    required DateTime start,
    required DateTime end,
    String? brandName,
    String? genericName,
    LatLngBounds? bbox,
    int hardLimit = 5000,
  }) async {
    // 1) Pull ADR rows within window (only fields we need)
    // Include common reaction columns so we can compute top side effects.
    const reactionCols = [
      'reactionDescription',
      'reaction_pt',
      'reaction',
      'adr_category',
      'adverse_reaction',
      'adverseReaction',
      'reactionTerm',
      'reportedReaction',
      'reaction_label',
    ];

    final selectCols =
        '$_colCreatedAt, medicineId, '
        'lat, latitude, geo_lat, lng, lon, longitude, geo_lng, '
        '${reactionCols.join(', ')}';

    final res = await sb
        .from(_tblReports)
        .select(selectCols)
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

    // 2) Collect unique medicineIds from ADR_Reports
    final medIds = <dynamic>{};
    for (final r in rows) {
      final id = r['medicineId'];
      if (id != null) medIds.add(id);
    }

    // 3) Build lookup: medicineId -> {brandName, genericName}
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

    // helpers
    double? _pickDouble(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is num) return v.toDouble();
        if (v is String) {
          final d = double.tryParse(v);
          if (d != null) return d;
        }
      }
      return null;
    }

    String? _pickReaction(Map<String, dynamic> m) {
      for (final k in reactionCols) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    String _clean(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');
    bool _junk(String s) {
      final v = s.trim().toLowerCase();
      return v.isEmpty ||
          v == 'reaction' ||
          v == 'unspecified' ||
          v == 'unknown' ||
          v == 'n/a' ||
          v == 'na';
    }

    const latKeys = ['lat', 'latitude', 'geo_lat', 'lat_deg'];
    const lngKeys = ['lng', 'lon', 'longitude', 'geo_lng', 'long', 'lng_deg'];

    // 4) Build points and side-effect tallies
    final pts = <TrendPoint>[];
    final counts = <String, int>{}; // key: "$drug|||$effect" → cases
    final displayDrug = <String, String>{}; // canonical drug key → display
    final displayEff = <String, String>{}; // canonical effect key → display

    String _canon(String s) => _clean(s).toLowerCase();

    for (final r in rows) {
      // coords (optional for clusters)
      final lat = _pickDouble(r, latKeys);
      final lng = _pickDouble(r, lngKeys);

      // medicine names
      final names =
          medMap[r['medicineId']] ?? const {'brand': '', 'generic': ''};
      final brand = names['brand'] ?? '';
      final generic = names['generic'] ?? '';
      final drugDisplay =
          brand.isNotEmpty ? brand : (generic.isNotEmpty ? generic : 'Unknown');
      final drugKey = _canon(drugDisplay);

      // reaction/effect
      final picked = _pickReaction(r) ?? 'Unspecified';
      final effDisplay = _junk(picked) ? 'Unspecified' : _clean(picked);
      final effKey = _canon(effDisplay);

      // Optional spatial clip
      if (lat != null && lng != null) {
        if (bbox != null) {
          final inside =
              lat >= bbox.south &&
              lat <= bbox.north &&
              lng >= bbox.west &&
              lng <= bbox.east;
          if (!inside) {
            // still include in top effects even if outside? keep behavior simple:
            // skip entirely when clipping by bbox.
            continue;
          }
        }
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

      // Filter by selected brand/generic (case-insensitive) BEFORE counting
      if ((brandName ?? '').trim().isNotEmpty) {
        final needle = brandName!.trim().toLowerCase();
        if (!brand.toLowerCase().contains(needle)) continue;
      }
      if ((genericName ?? '').trim().isNotEmpty) {
        final needle = genericName!.trim().toLowerCase();
        if (!generic.toLowerCase().contains(needle)) continue;
      }

      // Tally (drug, effect)
      final pairKey = '$drugKey|||$effKey';
      displayDrug[drugKey] = drugDisplay;
      displayEff[effKey] = effDisplay;
      counts.update(pairKey, (v) => v + 1, ifAbsent: () => 1);
    }

    // 5) Grid clustering (~5–6km) for the heat layer
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
        clusters.add(
          TrendCluster(
            center: LatLng(lat, lng),
            count: list.length,
            brandName: brand,
          ),
        );
      });
    }

    // 6) Top side effects
    final entries =
        counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // return up to, say, 50; UI clamps to 7 anyway
    final topEffects = <SideEffectCount>[];
    for (final e in entries.take(50)) {
      final parts = e.key.split('|||');
      final drug = displayDrug[parts[0]] ?? 'Unknown';
      final eff = displayEff[parts[1]] ?? 'Unspecified';
      topEffects.add(SideEffectCount(drug: drug, effect: eff, cases: e.value));
    }

    return TrendResult(clusters: clusters, topEffects: topEffects);
  }
}
