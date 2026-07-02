import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vybin/core/services/active_chat_tracker.dart';
import 'package:vybin/core/services/notification_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/onboarding/presentation/onboarding_screen.dart';
import 'package:vybin/shared/router/app_router.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';

class VybinApp extends StatefulWidget {
  final bool isFirstLaunch;
  const VybinApp({super.key, this.isFirstLaunch = false});

  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
  static final ValueNotifier<bool> onboardingCompleteNotifier = ValueNotifier(false);
  static final ValueNotifier<bool> showActivityStatusNotifier = ValueNotifier(true);

  @override
  State<VybinApp> createState() => _VybinAppState();
}

class _VybinAppState extends State<VybinApp> with WidgetsBindingObserver {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    VybinApp.onboardingCompleteNotifier.value = !widget.isFirstLaunch;
    final authBloc = context.read<AuthBloc>();
    _router = AppRouter.createRouter(authBloc);

    // Listen to notification taps when app is in the background
    if (Firebase.apps.isNotEmpty) {
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationRoute(message);
      });

      // Check if the app was opened from a terminated state via a notification
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          _handleNotificationRoute(message);
        }
      });

      // Listen to messages while the app is in the foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final senderUid = message.data['sender_uid'] as String?;
        if (senderUid == null) return;

        final myUid = FirebaseAuth.instance.currentUser?.uid;
        if (myUid == null) return;

        final sorted = [senderUid, myUid]..sort();
        final conversationId = sorted.join('_');

        // Active app suppression: if actively viewing this chat thread, suppress the notification
        if (ActiveChatTracker.activeConversationId == conversationId) {
          return;
        }

        // Decrypt and show local notification
        await NotificationService.decryptAndShowLocalNotification(message);
      });
    }

    SharedPreferences.getInstance().then((prefs) {
      final showStatus = prefs.getBool('show_activity_status') ?? true;
      VybinApp.showActivityStatusNotifier.value = showStatus;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    if (state == AppLifecycleState.resumed) {
      FirebaseFirestore.instance.collection('users').doc(myUid).update({
        'onlineStatus': 'online',
        'lastSeen': DateTime.now().toIso8601String(),
      });
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      FirebaseFirestore.instance.collection('users').doc(myUid).update({
        'onlineStatus': 'offline',
        'lastSeen': DateTime.now().toIso8601String(),
      });
    }
  }

  void _handleNotificationRoute(RemoteMessage message) {
    final conversationId = message.data['conversationId'] as String?;
    if (conversationId != null && conversationId.isNotEmpty) {
      _router.push('/chat/$conversationId', extra: {
        'contactName': message.data['contactName'] ?? 'Secure Chat',
        'contactAvatarInitials': message.data['contactAvatarInitials'] ?? '🔒',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: VybinApp.themeNotifier,
      builder: (context, currentMode, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: VybinApp.onboardingCompleteNotifier,
          builder: (context, isComplete, _) {
            if (!isComplete) {
              return MaterialApp(
                title: 'VYBIN',
                theme: VybinTheme.lightTheme,
                darkTheme: VybinTheme.darkTheme,
                themeMode: currentMode,
                home: const OnboardingScreen(),
                debugShowCheckedModeBanner: false,
              );
            } else {
              return MaterialApp.router(
                title: 'VYBIN',
                theme: VybinTheme.lightTheme,
                darkTheme: VybinTheme.darkTheme,
                themeMode: currentMode,
                routerConfig: _router,
                debugShowCheckedModeBanner: false,
              );
            }
          },
        );
      },
    );
  }
}
