import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_state.dart';
import 'package:vybin/features/auth/presentation/splash_screen.dart';
import 'package:vybin/features/auth/presentation/login_screen.dart';
import 'package:vybin/features/auth/presentation/signup_screen.dart';
import 'package:vybin/features/chat/presentation/chat_list_screen.dart';
import 'package:vybin/features/chat/presentation/individual_chat_screen.dart';

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

        final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup';
        final isSplash = state.matchedLocation == '/';

        if (authState is AuthInitializing) {
          // If initializing, keep user on splash screen
          return isSplash ? null : '/';
        }

        if (authState is AuthUnauthenticated || authState is AuthError) {
          // If not logged in, redirect to login unless already on auth screens
          return isLoggingIn ? null : '/login';
        }

        if (authState is AuthAuthenticated) {
          // If logged in, redirect to dashboard if on auth/splash screens
          return (isLoggingIn || isSplash) ? '/chats' : null;
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
          path: '/signup',
          builder: (context, state) => const SignUpScreen(),
        ),
        GoRoute(
          path: '/chats',
          builder: (context, state) => const ChatListScreen(),
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
      ],
    );
  }
}
