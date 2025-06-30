import 'package:flutter/material.dart';
import 'screens/report_form_screen.dart';

void main() {
  runApp(const GAMOTPHApp());
}

class GAMOTPHApp extends StatelessWidget {
  const GAMOTPHApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GAMOTPH ADR Reporter',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const ReportFormScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
