import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'views/login_page.dart';
import 'views/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    print('Firebase already initialized: $e');
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contacts Backup',
      theme: ThemeData(primarySwatch: Colors.blue),
      routes: {
        '/': (context) => const LoginPage(),
        '/home': (context) => HomePage(),
      },
    );
  }
}
