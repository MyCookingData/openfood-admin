import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:image_picker_for_web/image_picker_for_web.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/main_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    try {
      ImagePickerPlatform.instance = ImagePickerPlugin();
    } catch (e) {
      debugPrint('Registration of ImagePickerPlugin failed: $e');
    }
  }
  
  try {
    // Initialisation de Firebase avec le projet officiel client open-food-app-819c2
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
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.darkBackground,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.emeraldGreen),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const AdminVerificationScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

class AdminVerificationScreen extends StatefulWidget {
  const AdminVerificationScreen({super.key});

  @override
  State<AdminVerificationScreen> createState() => _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen> {
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
  }

  Future<void> _checkAdminRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        final role = data?['role']?.toString().toLowerCase();
        if (role == 'admin' || role == 'superadmin' || role == '99' || data?['isAdmin'] == true) {
          if (mounted) {
            setState(() {
              _isAdmin = true;
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Admin check error: $e');
    }

    if (mounted) {
      setState(() {
        _isAdmin = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.emeraldGreen),
        ),
      );
    }

    if (!_isAdmin) {
      return const LoginScreen();
    }

    return const MainDashboard();
  }
}
