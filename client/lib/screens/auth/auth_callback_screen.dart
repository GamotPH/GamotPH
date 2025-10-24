// lib/screens/auth/auth_callback_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(
        Uri.base,
        storeSession: true,
      );
    } catch (e) {
      // optional: show a toast/snackbar/log
    } finally {
      if (!mounted) return;
      // ✅ Go directly to Home
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
