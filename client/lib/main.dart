// lib/main.dart
// flutter run -d chrome --web-port=54296
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await supabase.Supabase.initialize(
    url: 'https://iposdbdgzyhduvqpbnjn.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlwb3NkYmRnenloZHV2cXBibmpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIyNTk1NzMsImV4cCI6MjA1NzgzNTU3M30.6tXiJXM2mSsUkM1wkQLZRHcb-9TvVvFuVvufuqAi1Rs',
  );

  // React to auth changes globally
  supabase.Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    if (event == supabase.AuthChangeEvent.signedIn) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
      );
    } else if (event == supabase.AuthChangeEvent.signedOut) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
    }
  });

  runApp(const ProviderScope(child: MyApp()));
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
