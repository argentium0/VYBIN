import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_state.dart';
import 'package:vybin/features/auth/presentation/splash_screen.dart';
import 'package:vybin/features/auth/presentation/login_screen.dart';
import 'package:vybin/features/auth/presentation/signup_screen.dart';
import 'package:vybin/features/auth/presentation/forgot_password_screen.dart';
import 'package:vybin/features/auth/presentation/email_verification_screen.dart';
import 'package:vybin/features/chat/bloc/chat_list_bloc.dart';
import 'package:vybin/features/chat/bloc/chat_list_event.dart';
import 'package:vybin/features/chat/data/chat_repository.dart';
import 'package:vybin/features/chat/presentation/chat_list_screen.dart';
import 'package:vybin/features/chat/presentation/individual_chat_screen.dart';
import 'package:vybin/features/chat/presentation/new_chat_screen.dart';
import 'package:vybin/features/profile/presentation/own_profile_screen.dart';
import 'package:vybin/features/settings/presentation/settings_screen.dart';
import 'package:vybin/features/chat/presentation/key_verification_screen.dart';

/// Helper to convert BLoC stream updates into a [Listenable] for [GoRouter].
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class AppRouter {
  AppRouter._();

  static GoRouter createRouter(AuthBloc authBloc) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      redirect: (context, state) {
        final authState = authBloc.state;

        final isLoggingIn = state.matchedLocation == '/login' ||
            state.matchedLocation == '/signup' ||
            state.matchedLocation == '/forgot-password';
        final isSplash = state.matchedLocation == '/';
        final isVerifyEmail = state.matchedLocation == '/verify-email';

        if (authState is AuthInitial) {
          // If initializing, keep user on splash screen
          return isSplash ? null : '/';
        }

        if (authState is AuthUnauthenticated || authState is AuthError) {
          // If not logged in, redirect to login unless already on auth screens
          return isLoggingIn ? null : '/login';
        }

        if (authState is AuthEmailUnverified) {
          // If email is unverified, redirect to verify-email unless on signup (for key dialog)
          if (state.matchedLocation == '/signup') {
            return null;
          }
          return isVerifyEmail ? null : '/verify-email';
        }

        if (authState is AuthAuthenticated) {
          // If logged in, redirect to dashboard if on auth/splash screens or verify-email
          return (isLoggingIn || isSplash || isVerifyEmail) ? '/chats' : null;
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/verify-email',
          builder: (context, state) => const EmailVerificationScreen(),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => const SignUpScreen(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/chats',
          builder: (context, state) {
            final authState = context.read<AuthBloc>().state;
            final currentUid = authState is AuthAuthenticated ? authState.user.uid : 'my_uid_123';
            final chatRepository = context.read<ChatRepository>();
            return BlocProvider(
              create: (context) => ChatListBloc(
                chatRepository: chatRepository,
                currentUid: currentUid,
              )..add(LoadConversations()),
              child: const ChatListScreen(),
            );
          },
        ),
        GoRoute(
          path: '/chat/:id',
          builder: (context, state) {
            final conversationId = state.pathParameters['id']!;
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return IndividualChatScreen(
              conversationId: conversationId,
              contactName: extra['contactName'] ?? 'Unknown',
              contactAvatarInitials: extra['contactAvatarInitials'] ?? '?',
            );
          },
        ),
        GoRoute(
          path: '/chat/:id/verify',
          builder: (context, state) {
            final conversationId = state.pathParameters['id']!;
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return KeyVerificationScreen(
              conversationId: conversationId,
              contactName: extra['contactName'] ?? 'Recipient',
            );
          },
        ),
        GoRoute(
          path: '/new-chat',
          builder: (context, state) => const NewChatScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const OwnProfileScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );
  }
}
