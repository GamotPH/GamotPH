// lib/screens/auth/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';
import 'register_screen.dart';
import '../dashboard/dashboard_screen.dart';

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
          return const DashboardScreen();
        }

        return Scaffold(
          appBar: AppBar(title: const Text("GAMOTPH"), centerTitle: true),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 40),
                    showRegister ? const RegisterScreen() : const LoginScreen(),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setState(() => showRegister = !showRegister);
                      },
                      child: Text(
                        showRegister
                            ? 'Already have an account? Login'
                            : 'Don’t have an account? Register',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
