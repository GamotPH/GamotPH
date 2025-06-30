// client/lib/screens/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../reports/report_form_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<List<dynamic>> getReports() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    print("✅ Current user ID: $userId");

    if (userId == null) return [];

    final response = await supabase
        .from('ADR_Reports')
        .select()
        .eq('userID', userId)
        .order('created_at', ascending: false);

    print("✅ Fetched reports: $response");

    return response;
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My ADR Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: getReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('❌ Error: ${snapshot.error}'));
          }

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return const Center(child: Text("No reports found."));
          }

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final createdAt = DateTime.tryParse(report['created_at'] ?? '');

              return ListTile(
                leading: const Icon(Icons.medical_services_outlined),
                title: Text(report['drugName'] ?? 'Unnamed Drug'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report['reactionDescription'] ?? ''),
                    if (createdAt != null)
                      Text(
                        'Reported: ${createdAt.toLocal().toString().substring(0, 16)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
