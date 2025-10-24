// lib/data/psgc_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class PsgcItem {
  final String code;
  final String name;
  const PsgcItem({required this.code, required this.name});

  factory PsgcItem.fromJson(Map<String, dynamic> j) =>
      PsgcItem(code: j['code']?.toString() ?? '', name: j['name'] ?? '');
}

class PsgcApi {
  static const _base = 'https://psgc.gitlab.io/api';

  Future<List<PsgcItem>> regions() async =>
      _list(await http.get(Uri.parse('$_base/regions/')));

  Future<List<PsgcItem>> provincesOfRegion(String regionCode) async =>
      _list(await http.get(Uri.parse('$_base/regions/$regionCode/provinces/')));

  Future<List<PsgcItem>> citiesOfProvince(String provinceCode) async => _list(
    await http.get(
      Uri.parse('$_base/provinces/$provinceCode/cities-municipalities/'),
    ),
  );

  /// Use this (instead of provinces) for NCR (130000000).
  Future<List<PsgcItem>> citiesOfRegion(String regionCode) async => _list(
    await http.get(
      Uri.parse('$_base/regions/$regionCode/cities-municipalities/'),
    ),
  );

  List<PsgcItem> _list(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('PSGC ${r.request?.url} -> ${r.statusCode} ${r.body}');
    }
    final data = json.decode(r.body) as List<dynamic>;
    return data
        .map((e) => PsgcItem.fromJson(e as Map<String, dynamic>))
        .where((e) => e.code.isNotEmpty && e.name.isNotEmpty)
        .toList();
  }
}
