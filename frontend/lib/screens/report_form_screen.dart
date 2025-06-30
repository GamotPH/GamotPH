import 'package:flutter/material.dart';

class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {
    "patientAge": "",
    "patientGender": "Male", // default value
    "drugName": "",
    "reactionDescription": "",
    "severity": "mild", // default value
    "geoLocation": "",
    "aiAssistance": true,
    "aiAssistanceResponse": "",
    "casePriorityScore": "",
  };

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      print(_formData); // Replace with API call
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Submitting ADR Report...")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("GAMOTPH: ADR Reporting")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: "Patient Age"),
                keyboardType: TextInputType.number,
                validator:
                    (val) => val == null || val.isEmpty ? "Required" : null,
                onSaved:
                    (val) => _formData["patientAge"] = int.tryParse(val ?? ""),
              ),
              DropdownButtonFormField<String>(
                value: _formData["patientGender"],
                decoration: const InputDecoration(labelText: "Gender"),
                items: const [
                  DropdownMenuItem(value: "Male", child: Text("Male")),
                  DropdownMenuItem(value: "Female", child: Text("Female")),
                ],
                onChanged:
                    (val) => setState(() => _formData["patientGender"] = val),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: "Drug Name"),
                validator:
                    (val) => val == null || val.isEmpty ? "Required" : null,
                onSaved: (val) => _formData["drugName"] = val,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Reaction Description",
                ),
                maxLines: 3,
                validator:
                    (val) => val == null || val.isEmpty ? "Required" : null,
                onSaved: (val) => _formData["reactionDescription"] = val,
              ),
              DropdownButtonFormField<String>(
                value: _formData["severity"],
                decoration: const InputDecoration(labelText: "Severity"),
                items: const [
                  DropdownMenuItem(value: "mild", child: Text("Mild")),
                  DropdownMenuItem(value: "moderate", child: Text("Moderate")),
                  DropdownMenuItem(value: "severe", child: Text("Severe")),
                ],
                onChanged: (val) => setState(() => _formData["severity"] = val),
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Location (e.g., Makati City)",
                ),
                validator:
                    (val) => val == null || val.isEmpty ? "Required" : null,
                onSaved: (val) => _formData["geoLocation"] = val,
              ),
              SwitchListTile(
                title: const Text("AI Assistance"),
                value: _formData["aiAssistance"],
                onChanged:
                    (val) => setState(() => _formData["aiAssistance"] = val),
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "AI Assistance Response",
                ),
                onSaved: (val) => _formData["aiAssistanceResponse"] = val,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Case Priority Score",
                ),
                keyboardType: TextInputType.number,
                onSaved:
                    (val) =>
                        _formData["casePriorityScore"] = double.tryParse(
                          val ?? "",
                        ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text("Submit"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
