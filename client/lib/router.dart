import 'package:client/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'layout/home_layout.dart';
import 'screens/auth/email_confirmation_success.dart';

Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/':
      return MaterialPageRoute(
        builder: (_) => const HomeLayout(), // always show this
      );

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
