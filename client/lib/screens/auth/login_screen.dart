// lib/screens/auth/login_screen.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
// Alias Supabase import
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// For LaunchMode.externalApplication on mobile OAuth
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

import '../../widgets/auth_input.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  void _showMessage(String message) {
    setState(() => _errorMessage = message);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _errorMessage = null);
    });
  }

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final res = await supabase.Supabase.instance.client.auth
          .signInWithPassword(
            email: email.text.trim(),
            password: password.text.trim(),
          );

      if (res.user != null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showMessage('Invalid email or password');
      }
    } on supabase.AuthException catch (e) {
      _showMessage('Login failed: ${e.message}');
    } catch (e) {
      _showMessage('Unexpected error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // NOTE: use sb.Provider (Supabase OAuth provider enum)
  Future<void> _loginWithOAuth(supabase.OAuthProvider provider) async {
    try {
      final client = supabase.Supabase.instance.client;

      if (kIsWeb) {
        final redirectTo = '${Uri.base.origin}/auth-callback';
        await client.auth.signInWithOAuth(provider, redirectTo: redirectTo);
      } else {
        await client.auth.signInWithOAuth(
          provider,
          authScreenLaunchMode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      _showMessage('OAuth login failed: $e');
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!emailRegex.hasMatch(value.trim()))
      return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // ⚠️ Make sure the asset name matches your pubspec entry exactly.
                      // You listed assets/GAMOTPH-LOGO.png (all caps LOGO) in pubspec.
                      // If needed, change the file name or this line to match.
                      Image.asset('assets/GAMOTPH-LOGO.png', height: 80),
                      const SizedBox(height: 48),
                      AuthInput(
                        controller: email,
                        labelText: "Email",
                        icon: Icons.email,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),
                      AuthInput(
                        controller: password,
                        labelText: "Password",
                        icon: Icons.lock,
                        obscureText: true,
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFDA7B),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child:
                              _isLoading
                                  ? const CircularProgressIndicator()
                                  : const Text(
                                    "LOGIN",
                                    style: TextStyle(fontSize: 16),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Or continue with',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const FaIcon(FontAwesomeIcons.google),
                            onPressed:
                                () => _loginWithOAuth(
                                  supabase.OAuthProvider.google,
                                ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const FaIcon(FontAwesomeIcons.facebook),
                            onPressed:
                                () => _loginWithOAuth(
                                  supabase.OAuthProvider.facebook,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Text('Register here'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_errorMessage != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 24,
                ),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
