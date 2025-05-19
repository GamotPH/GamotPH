import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://iposdbdgzyhduvqpbnjn.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlwb3NkYmRnenloZHV2cXBibmpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIyNTk1NzMsImV4cCI6MjA1NzgzNTU3M30.6tXiJXM2mSsUkM1wkQLZRHcb-9TvVvFuVvufuqAi1Rs',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GAMOTPH',
      debugShowCheckedModeBanner: false,
      home: const AuthGate(showRegister: false),
    );
  }
}
