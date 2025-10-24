import 'dart:html' as html;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocode/geocode.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../layout/home_layout.dart';

class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;

  // Controllers
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final contactController = TextEditingController();
  final weightController = TextEditingController();
  final dobController = TextEditingController();
  final geoLocationController = TextEditingController();

  final drugNameController = TextEditingController();
  final brandNameController = TextEditingController();
  final dosageController = TextEditingController();
  final routeController = TextEditingController();
  final reasonController = TextEditingController();

  final foodController = TextEditingController();
  final activitiesController = TextEditingController();
  final medsController = TextEditingController();
  final illnessController = TextEditingController();

  final symptomDescriptionController = TextEditingController();
  final reactionController = TextEditingController();
  final startDateController = TextEditingController();
  final endDateController = TextEditingController();
  final outcomeController = TextEditingController();

  String selectedSeverity = 'mild';
  bool isReportingForSelf = true;
  double? latitude;
  double? longitude;

  // OCR image
  Uint8List? ocrImageBytes;
  String? ocrImageName;

  @override
  void initState() {
    super.initState();
    _maybeAutofillLocation();
  }

  Future<void> _maybeAutofillLocation() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        latitude = position.latitude;
        longitude = position.longitude;

        await _reverseGeocode(latitude!, longitude!);
      } catch (e) {
        geoLocationController.text = "${latitude ?? '-'}, ${longitude ?? '-'}";
      }
    }
  }

  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lon&zoom=16&addressdetails=1',
      );

      // Nominatim requires a valid User-Agent with a way to contact you.
      final resp = await http.get(
        uri,
        headers: {
          'User-Agent': 'GAMOTPH/1.0 (contact: your-email@example.com)',
        },
      );

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>?;

        String line([String? v]) => (v ?? '').trim();

        final parts =
            [
              line(addr?['road']),
              line(addr?['suburb']),
              line(addr?['city']).isEmpty
                  ? line(addr?['town'])
                  : line(addr?['city']),
              line(addr?['state']),
              line(addr?['country']),
              line(addr?['postcode']),
            ].where((e) => e.isNotEmpty).toList();

        setState(() {
          geoLocationController.text =
              parts.isNotEmpty
                  ? '${parts.join(", ")} ($lat, $lon)'
                  : '$lat, $lon';
        });
      } else {
        // Fallback to raw coordinates
        setState(() => geoLocationController.text = '$lat, $lon');
      }
    } catch (_) {
      setState(() => geoLocationController.text = '$lat, $lon');
    }
  }

  void _uploadOCRImage() {
    html.FileUploadInputElement uploadInput =
        html.FileUploadInputElement()..accept = 'image/*';
    uploadInput.click();
    uploadInput.onChange.listen((e) {
      final file = uploadInput.files?.first;
      if (file != null) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        reader.onLoadEnd.listen((_) {
          setState(() {
            ocrImageBytes = reader.result as Uint8List;
            ocrImageName = file.name;
          });
        });
      }
    });
  }

  Future<void> submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;

    final data = {
      'userID': userId,
      'reported_for': isReportingForSelf ? 'myself' : 'someone_else',
      'patientName': nameController.text.trim(),
      'patientEmail': emailController.text.trim(),
      'contact': contactController.text.trim(),
      'weight': double.tryParse(weightController.text.trim()),
      'dob': dobController.text.trim(),
      'geoLocation': geoLocationController.text.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'drugName': drugNameController.text.trim(),
      'brandName': brandNameController.text.trim(),
      'dosage': dosageController.text.trim(),
      'administrationRoute': routeController.text.trim(),
      'reason': reasonController.text.trim(),
      'foodIntake': foodController.text.trim(),
      'activities': activitiesController.text.trim(),
      'otherMeds': medsController.text.trim(),
      'illnesses': illnessController.text.trim(),
      'symptomDescription': symptomDescriptionController.text.trim(),
      'reaction': reactionController.text.trim(),
      'startDate': startDateController.text.trim(),
      'endDate': endDateController.text.trim(),
      'outcome': outcomeController.text.trim(),
      'severity': selectedSeverity,
      'ocrFilename': ocrImageName,
    };

    await Supabase.instance.client.from('ADR_Reports').insert(data);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Report submitted successfully')),
      );
      context.findAncestorStateOfType<HomeLayoutState>()?.selectNav(
        NavItem.history,
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: keyboardType,
      validator:
          validator ?? (val) => val == null || val.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return Column(
          children: [
            SwitchListTile(
              title: const Text("Reporting for someone else"),
              value: !isReportingForSelf,
              onChanged: (val) => setState(() => isReportingForSelf = !val),
            ),
            _buildTextField(controller: nameController, label: 'Name'),
            _buildTextField(
              controller: emailController,
              label: 'Email',
              validator:
                  (val) =>
                      val == null || !val.contains('@')
                          ? 'Enter a valid email'
                          : null,
            ),
            _buildTextField(controller: contactController, label: 'Contact'),
            _buildTextField(
              controller: weightController,
              label: 'Weight (kg)',
              keyboardType: TextInputType.number,
            ),
            _buildTextField(controller: dobController, label: 'Date of Birth'),
            _buildTextField(
              controller: geoLocationController,
              label: 'Location',
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _uploadOCRImage,
                  icon: const Icon(Icons.upload),
                  label: const Text('Upload OCR Image'),
                ),
                const SizedBox(width: 8),
                if (ocrImageName != null) Text(ocrImageName!),
              ],
            ),
            if (ocrImageBytes != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Image.memory(ocrImageBytes!, height: 120),
              ),
            _buildTextField(controller: drugNameController, label: 'Drug Name'),
            _buildTextField(
              controller: brandNameController,
              label: 'Brand Name',
            ),
            _buildTextField(controller: dosageController, label: 'Dosage'),
            _buildTextField(
              controller: routeController,
              label: 'Administration Route',
            ),
            _buildTextField(
              controller: reasonController,
              label: 'Reasons for taking',
            ),
          ],
        );
      case 2:
        return Column(
          children: [
            _buildTextField(controller: foodController, label: 'Food intake'),
            _buildTextField(
              controller: activitiesController,
              label: 'Activities',
            ),
            _buildTextField(
              controller: medsController,
              label: 'Other Medications',
            ),
            _buildTextField(
              controller: illnessController,
              label: 'Current/Previous Illnesses',
            ),
          ],
        );
      case 3:
      default:
        return Column(
          children: [
            _buildTextField(
              controller: symptomDescriptionController,
              label: 'Symptom Description',
            ),
            _buildTextField(
              controller: reactionController,
              label: 'Reaction/Symptoms',
            ),
            _buildTextField(
              controller: startDateController,
              label: 'Start Date',
            ),
            _buildTextField(controller: endDateController, label: 'End Date'),
            _buildTextField(
              controller: outcomeController,
              label: 'Outcome of Reaction',
            ),
            DropdownButtonFormField<String>(
              value: selectedSeverity,
              decoration: const InputDecoration(labelText: 'Severity'),
              items: const [
                DropdownMenuItem(value: 'mild', child: Text('Mild')),
                DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                DropdownMenuItem(value: 'severe', child: Text('Severe')),
              ],
              onChanged:
                  (val) => setState(() => selectedSeverity = val ?? 'mild'),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ADR Reporting Form'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: PageView.builder(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          itemBuilder: (context, index) {
            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildPage(index),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentPage > 0)
                          ElevatedButton(
                            onPressed: () {
                              setState(() => _currentPage--);
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: const Text('Previous'),
                          ),
                        if (_currentPage < 3)
                          ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                setState(() => _currentPage++);
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                            child: const Text('Next'),
                          ),
                        if (_currentPage == 3)
                          ElevatedButton(
                            onPressed: submitReport,
                            child: const Text('Submit'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
