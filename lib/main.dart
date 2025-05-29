import 'package:contacts_app/views/contacts_page.dart';
import 'package:contacts_app/views/favorites_page.dart';
import 'package:contacts_app/views/sign_up_page.dart';
import 'package:contacts_app/views/sms_backup_page.dart';
import 'package:contacts_app/views/sms_page.dart';
import 'package:contacts_app/views/sms_restore_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'views/login_page.dart';
import 'views/home_page.dart';
import 'views/backup_page.dart';
import 'views/restore_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    print('Firebase already initialized: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contacts Backup',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/home': (context) => HomePage(),
        '/signup': (context) => const SignUpPage(),
        '/backup': (context) => const BackupPage(),
        '/restore': (context) => const RestorePage(),
        '/sms_backup': (context) => const SmsBackupPage(),
        '/sms_restore': (context) => const SmsRestorePage(),
        '/favorites': (context) => const FavoritesPage(),
        '/contacts': (context) => const ContactsPage(), // <-- nouvelle route
        '/sms': (context) => const SmsPage(),
      },
    );
  }
}
