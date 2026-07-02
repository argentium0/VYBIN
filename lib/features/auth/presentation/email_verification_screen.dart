import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_event.dart';
import 'package:vybin/features/auth/bloc/auth_state.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  bool _isChecking = false;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _cooldownSeconds = 60;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 1) {
        setState(() {
          _cooldownSeconds--;
        });
      } else {
        setState(() {
          _cooldownSeconds = 0;
        });
        _cooldownTimer?.cancel();
      }
    });
  }

  void _resendVerification() {
    if (_cooldownSeconds == 0) {
      context.read<AuthBloc>().add(ResendVerificationEmailRequested());
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Verification link resent successfully!'),
            ],
          ),
          backgroundColor: VybinTheme.whatsappGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _checkVerification() async {
    setState(() {
      _isChecking = true;
    });

    context.read<AuthBloc>().add(CheckEmailVerificationRequested());

    // We can reset checking state after a brief delay
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() {
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? VybinTheme.darkCharcoal : VybinTheme.lightBackground,
      appBar: AppBar(
        title: const Text('Email Verification'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthEmailUnverified && state.verificationError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.verificationError!)),
                  ],
                ),
                backgroundColor: VybinTheme.errorColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final email = state is AuthEmailUnverified ? state.user.email : 'your email';

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Card(
                  color: isDark ? VybinTheme.cardCharcoal : VybinTheme.lightCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Mail Icon Container
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: (isDark ? VybinTheme.neonHighlight : VybinTheme.whatsappTeal)
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.mark_email_unread_outlined,
                              size: 80,
                              color: isDark ? VybinTheme.neonHighlight : VybinTheme.whatsappTeal,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Headline
                        Text(
                          'Verify Your Identity',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Body Text
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.5,
                              color: isDark ? VybinTheme.primaryText : VybinTheme.lightPrimaryText,
                            ),
                            children: [
                              const TextSpan(
                                text: 'We have sent a verification link to:\n',
                              ),
                              TextSpan(
                                text: email,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: VybinTheme.neonHighlight,
                                ),
                              ),
                              const TextSpan(
                                text: '\n\nPlease verify your email to unlock end-to-end encrypted messaging features.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Primary Verification Check Button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? VybinTheme.neonHighlight : VybinTheme.whatsappTeal,
                            foregroundColor: isDark ? VybinTheme.darkCharcoal : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          onPressed: _isChecking ? null : _checkVerification,
                          child: _isChecking
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'I have verified my email',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        // Resend Verification Email Button
                        TextButton(
                          onPressed: _cooldownSeconds > 0 ? null : _resendVerification,
                          child: Text(
                            _cooldownSeconds > 0
                                ? 'Resend Verification Link ($_cooldownSeconds s)'
                                : 'Resend Verification Link',
                            style: TextStyle(
                              color: _cooldownSeconds > 0
                                  ? VybinTheme.secondaryText
                                  : (isDark ? VybinTheme.neonHighlight : VybinTheme.whatsappTeal),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Divider
                        const Divider(height: 24),
                        // Logout Text Button
                        TextButton(
                          onPressed: () {
                            context.read<AuthBloc>().add(LogoutRequested());
                          },
                          child: const Text(
                            'Logout',
                            style: TextStyle(
                              color: VybinTheme.errorColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
