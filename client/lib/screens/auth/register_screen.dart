import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/auth_input.dart';
import '../dashboard/dashboard_screen.dart';

// Register screen
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final email = TextEditingController();
  final password = TextEditingController();

  Future<void> register() async {
    final supabase = Supabase.instance.client;
    final res = await supabase.auth.signUp(
      email: email.text.trim(),
      password: password.text.trim(),
    );

    if (res.user != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check your email to confirm!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signup failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Create your GAMOTPH account",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          AuthInput(controller: email, labelText: "Email", icon: Icons.email),
          const SizedBox(height: 16),
          AuthInput(
            controller: password,
            labelText: "Password",
            icon: Icons.lock,
            obscureText: true,
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: register,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003366),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Register", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
