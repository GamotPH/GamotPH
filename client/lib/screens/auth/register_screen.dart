// lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
// import 'package:url_launcher/url_launcher.dart' show LaunchMode;

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
  final organization = TextEditingController();

  bool _isLoading = false;

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  String? _selectedOrganization;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    organization.dispose();
    super.dispose();
  }

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;

    final client = supabase.Supabase.instance.client;
    final emailText = email.text.trim();
    final passwordText = password.text.trim();
    final orgText = organization.text.trim();

    setState(() => _isLoading = true);

    try {
      final res = await client.auth.signUp(
        email: emailText,
        password: passwordText,
        data: {
          'requested_org': orgText, // ⭐ sent to metadata → trigger uses this
        },
        emailRedirectTo:
            'http://localhost:50565/email-confirmed', // your callback
      );

      if (res.user != null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Check your email to confirm your account.'),
          ),
        );

        Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('❌ Signup failed')));
      }
    } on supabase.AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Future<void> _signUpWithOAuth(supabase.OAuthProvider provider) async {
  //   try {
  //     await supabase.Supabase.instance.client.auth.signInWithOAuth(
  //       provider,
  //       redirectTo: 'http://localhost:54321/auth/callback',
  //       authScreenLaunchMode: LaunchMode.externalApplication,
  //     );
  //   } catch (e) {
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(SnackBar(content: Text('OAuth signup failed: $e')));
  //   }
  // }

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

  String? _validateOrganization(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Organization is required';
    }
    if (value.trim().length < 3) {
      return 'Please enter a valid organization name';
    }
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
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: password,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _hidePassword = !_hidePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _hidePassword,
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password
                  TextFormField(
                    controller: confirmPassword,
                    decoration: InputDecoration(
                      labelText: "Confirm Password",
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _hideConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _hideConfirmPassword = !_hideConfirmPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _hideConfirmPassword,
                    validator: _validateConfirmPassword,
                  ),

                  const SizedBox(height: 16),

                  // Organization
                  DropdownButtonFormField<String>(
                    value: _selectedOrganization,
                    decoration: const InputDecoration(
                      labelText: "Organization",
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Pharma Company',
                        child: Text('Pharma Company'),
                      ),
                      DropdownMenuItem(value: 'FDA', child: Text('FDA')),
                      DropdownMenuItem(value: 'DOH', child: Text('DOH')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedOrganization = value;
                        organization.text =
                            value ?? ''; // ⭐ keeps backend logic unchanged
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Organization is required';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 28),

                  // Register button
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

                  // const SizedBox(height: 24),
                  // const Text(
                  //   'Or sign up with',
                  //   style: TextStyle(color: Colors.black54),
                  // ),
                  // const SizedBox(height: 12),

                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.center,
                  //   children: [
                  //     IconButton(
                  //       icon: const FaIcon(FontAwesomeIcons.google),
                  //       onPressed:
                  //           () =>
                  //               _signUpWithOAuth(supabase.OAuthProvider.google),
                  //     ),
                  //     const SizedBox(width: 16),
                  //     IconButton(
                  //       icon: const FaIcon(FontAwesomeIcons.facebook),
                  //       onPressed:
                  //           () => _signUpWithOAuth(
                  //             supabase.OAuthProvider.facebook,
                  //           ),
                  //     ),
                  //   ],
                  // ),
                  const SizedBox(height: 24),
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
