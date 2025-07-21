import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../layout/home_layout.dart';

class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final ageController = TextEditingController();
  final weightController = TextEditingController();
  final drugNameController = TextEditingController();
  final reactionController = TextEditingController();
  final geoLocationController = TextEditingController();
  final aiResponseController = TextEditingController();
  final priorityScoreController = TextEditingController();

  String selectedGender = 'Male';
  String selectedSeverity = 'mild';
  bool aiAssistance = true;

  Future<void> submitReport() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    final data = {
      'userID': userId,
      'patientAge': int.tryParse(ageController.text.trim()),
      'patientGender': selectedGender,
      'patientWeight': double.tryParse(weightController.text.trim()),
      'drugName': drugNameController.text.trim(),
      'reactionDescription': reactionController.text.trim(),
      'severity': selectedSeverity,
      'geoLocation': geoLocationController.text.trim(),
      'aiAssistance': aiAssistance,
      'aiAssistanceResponse': aiResponseController.text.trim(),
      'casePriorityScore': double.tryParse(priorityScoreController.text.trim()),
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      await Supabase.instance.client.from('ADR_Reports').insert(data);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Report submitted successfully')),
      );

      if (userId != null) {
        // ✅ Change tab to history instead of pushing new route
        final state = context.findAncestorStateOfType<HomeLayoutState>();
        state?.selectNav(NavItem.history);
      } else {
        // ❌ Anonymous user → Show message then redirect to home
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ You must be logged in to see the ADR reports.'),
            duration: Duration(seconds: 5),
          ),
        );

        await Future.delayed(const Duration(seconds: 5));
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final layoutState = context.findAncestorStateOfType<HomeLayoutState>();

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24), // Add vertical spacing below divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextButton.icon(
              onPressed: () {
                layoutState?.selectNav(NavItem.home); // Back to tile view
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
              style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: ageController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Patient Age',
                          ),
                          validator:
                              (val) =>
                                  val == null || val.isEmpty
                                      ? 'Required'
                                      : null,
                        ),
                        TextFormField(
                          controller: weightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Patient Weight (kg)',
                          ),
                          validator:
                              (val) =>
                                  val == null || val.isEmpty
                                      ? 'Required'
                                      : null,
                        ),
                        DropdownButtonFormField<String>(
                          value: selectedGender,
                          decoration: const InputDecoration(
                            labelText: 'Gender',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Male',
                              child: Text('Male'),
                            ),
                            DropdownMenuItem(
                              value: 'Female',
                              child: Text('Female'),
                            ),
                          ],
                          onChanged:
                              (val) => setState(() => selectedGender = val!),
                        ),
                        TextFormField(
                          controller: drugNameController,
                          decoration: const InputDecoration(
                            labelText: 'Drug Name',
                          ),
                          validator:
                              (val) =>
                                  val == null || val.isEmpty
                                      ? 'Required'
                                      : null,
                        ),
                        TextFormField(
                          controller: reactionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Reaction Description',
                          ),
                          validator:
                              (val) =>
                                  val == null || val.isEmpty
                                      ? 'Required'
                                      : null,
                        ),
                        DropdownButtonFormField<String>(
                          value: selectedSeverity,
                          decoration: const InputDecoration(
                            labelText: 'Severity',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'mild',
                              child: Text('Mild'),
                            ),
                            DropdownMenuItem(
                              value: 'moderate',
                              child: Text('Moderate'),
                            ),
                            DropdownMenuItem(
                              value: 'severe',
                              child: Text('Severe'),
                            ),
                          ],
                          onChanged:
                              (val) => setState(
                                () => selectedSeverity = val ?? 'mild',
                              ),
                        ),
                        TextFormField(
                          controller: geoLocationController,
                          decoration: const InputDecoration(
                            labelText: 'Location (e.g., Makati City)',
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState?.validate() ?? false) {
                              submitReport();
                            }
                          },
                          child: const Text('Submit'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
