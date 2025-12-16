// client/lib/data/top_adr.dart

class TopAdr {
  final String label;
  final int count;

  const TopAdr({required this.label, required this.count});

  factory TopAdr.fromJson(Map<String, dynamic> json) {
    return TopAdr(label: json['label'] as String, count: json['count'] as int);
  }
}
