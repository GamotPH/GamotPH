// lib/router.dart
import 'package:flutter/material.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/auth/auth_callback_screen.dart';
import 'screens/auth/email_confirmation_success.dart';

Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/':
      return MaterialPageRoute(builder: (_) => const AuthGate(showRegister: false));

    case '/home':
      return MaterialPageRoute(builder: (_) => const AuthGate(showRegister: false));

    case '/auth-callback':
      // Google OAuth callback
      return MaterialPageRoute(builder: (_) => const AuthCallbackScreen());

    case '/email-confirmed':
      return MaterialPageRoute(
        builder: (_) => const EmailConfirmationSuccessScreen(),
      );

    default:
      return MaterialPageRoute(
        builder:
            (_) => const Scaffold(body: Center(child: Text('Page not found'))),
      );
  }
}
