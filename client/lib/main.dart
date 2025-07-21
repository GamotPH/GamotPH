import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'layout/home_layout.dart';
import 'router.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://iposdbdgzyhduvqpbnjn.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlwb3NkYmRnenloZHV2cXBibmpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIyNTk1NzMsImV4cCI6MjA1NzgzNTU3M30.6tXiJXM2mSsUkM1wkQLZRHcb-9TvVvFuVvufuqAi1Rs',
  );

  // ✅ Safely handle OAuth redirect only if the URL has access_token
  final uri = Uri.base;
  if (uri.fragment.contains('access_token')) {
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
    } catch (e) {
      debugPrint('OAuth redirect error: $e');
    }
  }

  runApp(const MyApp());

  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final session = data.session;
    final event = data.event;

    if (event == AuthChangeEvent.signedIn && session != null) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeLayout()),
        (route) => false,
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          ScaffoldMessenger.of(
            ctx,
          ).showSnackBar(const SnackBar(content: Text('✅ Login successful')));
        }
      });
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GAMOTPH',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      onGenerateRoute: generateRoute,
    );
  }
}
