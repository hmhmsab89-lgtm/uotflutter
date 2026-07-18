import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/supabase_service.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/call_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (Requires google-services.json or firebase_options.dart)
  try {
    await Firebase.initializeApp();
    await NotificationService().init();
    await CallService().init();
  } catch (e) {
    print("Firebase initialization failed. Please ensure Firebase is configured: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SupabaseService()),
      ],
      child: MaterialApp(
        title: 'الحرم الذكي - uotTransToFlutter',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E3A8A), // Navy base
            primary: const Color(0xFF1E3A8A),
            secondary: const Color(0xFF3B82F6),
            background: const Color(0xFFF8FAFC), // Off-white
          ),
          fontFamily: 'Rubik', // Standard premium Arabic typography fallback
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        // Visual Entry check routing
        home: const SplashScreen(),
      ),
    );
  }
}
