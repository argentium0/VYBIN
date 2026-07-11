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
import 'package:vybin/features/auth/bloc/auth_state.dart';
import 'package:vybin/features/onboarding/presentation/onboarding_screen.dart';
import 'package:vybin/shared/router/app_router.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';
import 'package:vybin/main.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:vybin/core/services/zego_signaling_extension.dart';
import 'dart:async';
import 'dart:convert';

const int zegoAppID = 1912280269;
const String zegoAppSign =
    '681148e550ddad441123817ece4a591eb10a5924ea836cb83a45008fde16f501';

class VybinApp extends StatefulWidget {
  final bool isFirstLaunch;
  const VybinApp({super.key, this.isFirstLaunch = false});

  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    ThemeMode.dark,
  );
  static final ValueNotifier<bool> onboardingCompleteNotifier = ValueNotifier(
    false,
  );
  static final ValueNotifier<bool> showActivityStatusNotifier = ValueNotifier(
    true,
  );

  @override
  State<VybinApp> createState() => _VybinAppState();
}

class _VybinAppState extends State<VybinApp> with WidgetsBindingObserver {
  late final GoRouter _router;
  StreamSubscription? _signalingSubscription;

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
      FirebaseMessaging.instance.getInitialMessage().then((
        RemoteMessage? message,
      ) {
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
    _signalingSubscription?.cancel();
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
      _router.push(
        '/chat/$conversationId',
        extra: {
          'contactName': message.data['contactName'] ?? 'Secure Chat',
          'contactAvatarInitials':
              message.data['contactAvatarInitials'] ?? '🔒',
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) async {
        if (state is AuthAuthenticated) {
          try {
            ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(navigatorKey);
            await ZegoUIKitPrebuiltCallInvitationService().useSystemCallingUI([ZegoUIKitSignalingPlugin()]);
            await ZegoUIKitPrebuiltCallInvitationService().init(
              appID: zegoAppID,
              appSign: zegoAppSign,
              userID: state.user.uid,
              userName: state.user.username,
              plugins: [ZegoUIKitSignalingPlugin()],
              requireConfig: (ZegoCallInvitationData data) {
                final config = data.type == ZegoCallInvitationType.videoCall
                    ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
                    : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

                config.layout = ZegoLayout.pictureInPicture(
                  smallViewPosition: ZegoViewPosition.bottomRight,
                );

                config.topMenuBar = ZegoCallTopMenuBarConfig(
                  isVisible: true,
                  buttons: [
                    ZegoCallMenuBarButtonName.minimizingButton,
                  ],
                );

                config
                    .audioVideoView
                    .foregroundBuilder = (context, size, user, extraInfo) {
                  // If the width is less than 300, it is the small PiP overlay. Hide the text!
                  if (size.width < 300) {
                    return const SizedBox.shrink();
                  }

                  return Stack(
                    children: [
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 10,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(0, 0, 0, 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '🔒 Voice calls are secured in transit, but are NOT End-to-End Encrypted.',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  );
                };

                return config;
              },
            );
            // ignore: avoid_print
            print("✅ ZEGO INITIALIZED SUCCESSFULLY");

            ZegoUIKitSignalingPlugin().setupPeerToRoomCommandBridge();
            _signalingSubscription?.cancel();
            _signalingSubscription = ZegoUIKitSignalingPlugin()
                .getInRoomCommandMessageReceivedEventStream()
                .listen((event) async {
              for (final msg in event.messages) {
                try {
                  final commandData = jsonDecode(utf8.decode(msg.message)) as Map<String, dynamic>;
                  if (commandData['type'] == 'new_text') {
                    await NotificationService.showNotification(
                      id: DateTime.now().millisecondsSinceEpoch.hashCode,
                      title: 'New Encrypted Message',
                      body: 'New Encrypted Message',
                    );
                  }
                } catch (e) {
                  debugPrint('Failed to parse command message: $e');
                }
              }
            });
          } catch (e) {
            // ignore: avoid_print
            print("❌ ZEGO INIT ERROR: $e");
          }
        } else if (state is AuthUnauthenticated ||
            state is AuthLoggedOutState) {
          _signalingSubscription?.cancel();
          _signalingSubscription = null;
          ZegoUIKitPrebuiltCallInvitationService().uninit();
        }
      },
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: VybinApp.themeNotifier,
        builder: (context, currentMode, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: VybinApp.onboardingCompleteNotifier,
            builder: (context, isComplete, _) {
              if (!isComplete) {
                return MaterialApp(
                  navigatorKey: navigatorKey,
                  title: 'VYBIN',
                  theme: VybinTheme.lightTheme,
                  darkTheme: VybinTheme.darkTheme,
                  themeMode: currentMode,
                  home: const OnboardingScreen(),
                  debugShowCheckedModeBanner: false,
                  builder: (BuildContext context, Widget? child) {
                    return Stack(
                      children: [
                        child!,
                        ZegoUIKitPrebuiltCallMiniOverlayPage(
                          contextQuery: () {
                            return navigatorKey.currentState!.context;
                          },
                        ),
                      ],
                    );
                  },
                );
              } else {
                return MaterialApp.router(
                  title: 'VYBIN',
                  theme: VybinTheme.lightTheme,
                  darkTheme: VybinTheme.darkTheme,
                  themeMode: currentMode,
                  routerConfig: _router,
                  debugShowCheckedModeBanner: false,
                  builder: (BuildContext context, Widget? child) {
                    return Stack(
                      children: [
                        child!,
                        ZegoUIKitPrebuiltCallMiniOverlayPage(
                          contextQuery: () {
                            return navigatorKey.currentState!.context;
                          },
                        ),
                      ],
                    );
                  },
                );
              }
            },
          );
        },
      ),
    );
  }
}
