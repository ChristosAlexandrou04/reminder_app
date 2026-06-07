import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'homepage.dart';
import 'login_page.dart';
import 'app_settings.dart';
import 'alarm_service.dart';
import 'notification_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _lastUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          _lastUid = null;
          return const LoginPage();
        }

        // Only run side-effects when the signed-in user actually changes.
        if (user.uid != _lastUid) {
          _lastUid = user.uid;
          AppSettings.loadFromFirestore(user.uid);
          if (!kIsWeb && !Platform.isWindows) AlarmService.instance.start();
          NotificationService.instance.scheduleAll();
        }

        return const HomePage();
      },
    );
  }
}
