import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart'; // Added for kIsWeb
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:path_provider/path_provider.dart'; // Removed (used in crash_logger)
import 'package:shared_preferences/shared_preferences.dart'; 
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_layout.dart';
import 'core/utils/crash_logger.dart'; // Added

// Firebase Config
const firebaseConfig = FirebaseOptions(
  apiKey: "AIzaSyBpV0rVE9muImAgC3c4qRppxZUymNTY8oA",
  authDomain: "life-style-pos.firebaseapp.com",
  projectId: "life-style-pos",
  storageBucket: "life-style-pos.firebasestorage.app",
  messagingSenderId: "934734657009",
  appId: "1:934734657009:web:f2f272e78fe8d03d6b8050",
);

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // safe guard for release mode errors not showing red screen
    ErrorWidget.builder = (FlutterErrorDetails details) {
       return Material(
         child: Container(
           color: Colors.white,
           child: Center(
             child: Text(
               'An error occurred:\n${details.exception}', 
               style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
               textAlign: TextAlign.center,
             ),
           ),
         ),
       );
    };

    try {
      await Firebase.initializeApp(
        options: firebaseConfig,
      );

      // Fix for "non-platform thread" crash on Windows (Only apply on Windows Native)
      // kIsWeb is false on Windows Desktop.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
      }
      
      // Pass all uncaught errors from the framework to Crashlytics or non-fatal logs
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        // Log synchronous errors
        logErrorToFile(details.exception, details.stack ?? StackTrace.empty);
      };

      // Force Logout on First Run (After Installation)
      try {
         final prefs = await SharedPreferences.getInstance();
         final isFirstRun = prefs.getBool('first_run') ?? true;
         if (isFirstRun) {
            await FirebaseAuth.instance.signOut();
            await prefs.setBool('first_run', false);
            debugPrint('First Run detected: User signed out to ensure fresh login.');
         }
      } catch (e) {
        debugPrint('Error checking first run: $e');
      }

      runApp(const ProviderScope(child: MyApp()));
    } catch (e) {
      runApp(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Firebase Initialization Error:\n$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 18),
              ),
            ),
          ),
        ),
      ));
    }
  }, (error, stack) {
    // Catch-all for async errors
    debugPrint('Global Async Error: $error');
    debugPrint('Stack: $stack');
    
    // Log to file for debugging release builds (Handled nicely via crash_logger)
    logErrorToFile(error, stack);
  });
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Life Style POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const DashboardLayout();
          } else {
            return const LoginScreen();
          }
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, stack) => Scaffold(
          body: Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}
