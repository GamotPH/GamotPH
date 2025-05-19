import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/extensions.dart';

class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final drugNameController = TextEditingController();
  final reactionController = TextEditingController();
  String selectedSeverity = 'mild'; // ✅ lowercase values

  Future<void> submitReport() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final data = {
      'userID': userId,
      'drugName': drugNameController.text.trim(),
      'reactionDescription': reactionController.text.trim(),
      'severity': selectedSeverity,
      'geoLocation': 'Unknown', // Optional: replace with geolocation if needed
      'created_at': DateTime.now().toIso8601String(),
    };

    final response = await Supabase.instance.client
        .from('ADR_Reports')
        .insert(data);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted successfully')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report ADR')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: drugNameController,
                decoration: const InputDecoration(
                  labelText: 'Drug Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reactionController,
                decoration: const InputDecoration(
                  labelText: 'Reaction Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedSeverity,
                decoration: const InputDecoration(
                  labelText: 'Severity',
                  border: OutlineInputBorder(),
                ),
                items:
                    ['mild', 'moderate', 'severe']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              value[0].toUpperCase() + value.substring(1),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (val) => setState(() => selectedSeverity = val!),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    submitReport();
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text('Submit Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
