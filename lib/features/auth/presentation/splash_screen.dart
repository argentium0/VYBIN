import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_event.dart';
import 'package:vybin/features/auth/bloc/auth_state.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    context.read<AuthBloc>().add(AppStarted());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          context.go('/login');
        } else if (state is AuthAuthenticated) {
          context.go('/chats');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                Theme.of(context).brightness == Brightness.dark
                    ? 'assets/images/logo_dark.png'
                    : 'assets/images/logo.png',
                height: 110,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.chat_bubble,
                        color: VybinTheme.whatsappDarkTeal,
                        size: 110,
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12.0),
                        child: Icon(Icons.lock, color: Colors.white, size: 45),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              Text(
                'VYBIN',
                style: VybinTheme.headline1.copyWith(
                  letterSpacing: 2.0,
                  color: VybinTheme.whatsappDarkTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Privacy-First Encrypted Chat',
                style: VybinTheme.caption.copyWith(
                  color: VybinTheme.whatsappTeal,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),

              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: VybinTheme.whatsappDarkTeal,
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
