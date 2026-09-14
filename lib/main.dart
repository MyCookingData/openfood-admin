import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialisation de Firebase avec vos véritables clés de projet
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyCaAfkg8zLlK8gU42rDJ4zeieZ4xXtXp-k',
        appId: '1:809394357365:web:60927b7eb4a158e23f643c',
        messagingSenderId: '809394357365',
        projectId: 'open-food-app-819c2',
        authDomain: 'open-food-app-819c2.firebaseapp.com',
        storageBucket: 'open-food-app-819c2.firebasestorage.app',
      ),
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(const OpenFoodAdminApp());
}

class OpenFoodAdminApp extends StatelessWidget {
  const OpenFoodAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenFood Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const LoginScreen(),
    );
  }
}
