// lib/screens/auth/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../layout/home_layout.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class AuthGate extends StatefulWidget {
  final bool showRegister;

  const AuthGate({super.key, required this.showRegister});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late bool showRegister;

  @override
  void initState() {
    super.initState();
    showRegister = widget.showRegister;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        if (session != null) {
          return const HomeLayout();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return showRegister ? const RegisterScreen() : const LoginScreen();
      },
    );
  }
}
