import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'features/auth/services/auth_service.dart';
import 'features/sync/services/sync_service.dart';
import 'features/tracking/presentation/trail_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize progressive anonymous auth (Guest mode)
    final authService = AuthService();
    await authService.initializeGuestAuth();

    // Initialize background network monitoring & deferred sync engine
    final syncService = SyncService();
    syncService.initialize();
  } catch (e) {
    // Gracefully continue offline if Firebase or network is unavailable
    // ignore: avoid_print
    print('[Trailwire] Startup offline mode note: $e');
  }

  runApp(const TrailwireApp());
}

class TrailwireApp extends StatelessWidget {
  const TrailwireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trailwire',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F12),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676), // Neon mint
          secondary: Color(0xFF38BDF8), // Cyan
          surface: Color(0xFF0F172A),
          error: Color(0xFFEF4444),
        ),
      ),
      home: const TrailScreen(),
    );
  }
}
