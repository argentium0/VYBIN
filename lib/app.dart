import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
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

class _VybinAppState extends State<VybinApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    VybinApp.onboardingCompleteNotifier.value = !widget.isFirstLaunch;
    final authBloc = context.read<AuthBloc>();
    _router = AppRouter.createRouter(authBloc);

    // Listen to notification taps when app is in the background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationRoute(message);
    });

    // Check if the app was opened from a terminated state via a notification
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleNotificationRoute(message);
      }
    });

    SharedPreferences.getInstance().then((prefs) {
      final showStatus = prefs.getBool('show_activity_status') ?? true;
      VybinApp.showActivityStatusNotifier.value = showStatus;
    });
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
