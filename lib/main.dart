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
        apiKey: 'AIzaSyA49Q5B4nF8K2OZtDoxUsmELpAb0zZUZbc',
        appId: '1:178517740611:web:09dfba077107c07f59d8f6',
        messagingSenderId: '178517740611',
        projectId: 'app-openfood',
        authDomain: 'app-openfood.firebaseapp.com',
        storageBucket: 'app-openfood.firebasestorage.app',
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
