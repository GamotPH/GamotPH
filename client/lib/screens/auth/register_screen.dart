// lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// Alias Supabase so we can use supabase.Provider without clashing with Riverpod
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
// For LaunchMode.externalApplication on mobile OAuth
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  bool _isLoading = false;

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;

    final client = supabase.Supabase.instance.client;
    final emailText = email.text.trim();
    final passwordText = password.text.trim();

    setState(() => _isLoading = true);
    try {
      final res = await client.auth.signUp(
        email: emailText,
        password: passwordText,
        // Adjust this to your deployed callback if needed
        emailRedirectTo: 'http://localhost:50565/email-confirmed',
      );

      if (res.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Check your email to confirm your account.'),
          ),
        );
        if (mounted) Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('❌ Signup failed')));
      }
    } on supabase.AuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Use the Supabase OAuth provider enum through the alias
  Future<void> _signUpWithOAuth(supabase.OAuthProvider provider) async {
    try {
      await supabase.Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: 'http://localhost:54321/auth/callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('OAuth signup failed: $e')));
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) return 'Password is required';
    if (value.trim().length < 6) return 'Must be at least 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != password.text) return 'Passwords do not match';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Logo (ensure this matches the filename in pubspec)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Image.asset(
                      'assets/GAMOTPH-LOGO.png',
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const Text(
                    "Create your account",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),

                  // Email
                  TextFormField(
                    controller: email,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: password,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password
                  TextFormField(
                    controller: confirmPassword,
                    decoration: const InputDecoration(
                      labelText: "Confirm Password",
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: _validateConfirmPassword,
                  ),
                  const SizedBox(height: 28),

                  // Register Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003366),
                        foregroundColor: const Color(0xFFFFDA7B),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:
                          _isLoading
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : const Text(
                                "Register",
                                style: TextStyle(fontSize: 16),
                              ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // OAuth Separator
                  const Text(
                    'Or sign up with',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 12),

                  // OAuth Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const FaIcon(FontAwesomeIcons.google),
                        onPressed:
                            () =>
                                _signUpWithOAuth(supabase.OAuthProvider.google),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const FaIcon(FontAwesomeIcons.facebook),
                        onPressed:
                            () => _signUpWithOAuth(
                              supabase.OAuthProvider.facebook,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Already have an account
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account?"),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Login'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
