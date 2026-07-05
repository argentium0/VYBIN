import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vybin/app.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/auth/data/auth_repository.dart';
import 'package:vybin/features/chat/data/chat_repository.dart';
import 'package:vybin/core/services/encryption_service.dart';
import 'package:vybin/core/services/notification_service.dart';
import 'package:vybin/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Override Flutter's default error widget to avoid Red Screen of Death
  ErrorWidget.builder = (FlutterErrorDetails details) {
    bool isRelease = const bool.fromEnvironment('dart.vm.product');
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: const Color(0xFF121212),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFF5252),
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Oops, something went wrong.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (!isRelease) ...[
                  const SizedBox(height: 16),
                  Text(
                    details.exceptionAsString(),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  };

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.initialize();
  FirebaseMessaging.onBackgroundMessage(anonymizedBackgroundMessageHandler);

  // Request push notification permissions
  final messaging = FirebaseMessaging.instance;
  try {
    await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  } catch (e) {
    debugPrint('Error requesting notification permission: $e');
  }

  // Listen to auth state changes to save FCM token to current user's Firestore document
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'fcmToken': token}, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('Error saving FCM token: $e');
      }
    }
  });

  // Listen to token refreshes to keep Firestore updated
  FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error updating refreshed FCM token: $e');
      }
    }
  });

  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

  final encryptionService = EncryptionService();
  final authRepository = AuthRepository(encryptionService: encryptionService);
  final chatRepository = ChatRepository(encryptionService: encryptionService);

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(create: (_) => authRepository),
        RepositoryProvider<ChatRepository>(create: (_) => chatRepository),
      ],
      child: BlocProvider(
        create: (context) => AuthBloc(authRepository: authRepository),
        child: VybinApp(isFirstLaunch: isFirstLaunch),
      ),
    ),
  );
}
