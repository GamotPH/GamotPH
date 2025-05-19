import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class AuthGate extends StatelessWidget {
  final bool showRegister;
  const AuthGate({super.key, required this.showRegister});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // LEFT SIDE (LOGOS)
          Expanded(
            flex: 1,
            child: Container(
              color: const Color(0xFFE6EEF4),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/dost_logo.png', height: 80),
                    const SizedBox(height: 30),
                    Image.asset('assets/bagong_pilipinas_logo.png', height: 80),
                    const SizedBox(height: 30),
                    Image.asset(
                      'assets/national_university_logo.png',
                      height: 80,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // RIGHT SIDE (FORM)
          Expanded(
            flex: 1,
            child: Container(
              color: const Color(0xFFFCF7FB),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'GAMOTPH',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineLarge?.copyWith(
                            color: Colors.blue[900],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 40),
                        showRegister
                            ? const RegisterScreen()
                            : const LoginScreen(),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        AuthGate(showRegister: !showRegister),
                              ),
                            );
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
            ),
          ),
        ],
      ),
    );
  }
}
