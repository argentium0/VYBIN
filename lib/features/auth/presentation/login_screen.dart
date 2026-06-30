import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_event.dart';
import 'package:vybin/features/auth/bloc/auth_state.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Email validation helper
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // Password validation helper
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    return null;
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
        LoginRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: VybinTheme.errorColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Reset Password',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          content: Text(
            '⚠️ Resetting your password will make your existing chat history permanently unreadable, '
            'because your messages are encrypted with a key derived from your password.\n\n'
            'Only proceed if you are okay with losing access to previous conversations.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
            ),
          ),
          actions: [
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(color: VybinTheme.secondaryText),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: VybinTheme.errorColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('I Understand'),
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Password reset email simulated successfully.',
                    ),
                    backgroundColor: VybinTheme.neonHighlight,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VybinTheme.darkCharcoal,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            // Contextual Snackbar on auth failure
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.errorMessage)),
                  ],
                ),
                backgroundColor: VybinTheme.errorColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          } else if (state is AuthAuthenticated) {
            // Contextual AlertDialog popup on simulated success
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color: VybinTheme.whatsappGreen,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Access Granted',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back, ${state.user.displayName}!',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Secure local keys storage has been initialized, and your RSA-2048 identity keypair has been verified.\n\n'
                        'All chat sessions in VYBIN are secured with peer-to-peer end-to-end encryption.',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.85),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VybinTheme.whatsappGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Enter VYBIN'),
                      onPressed: () {
                        Navigator.of(context).pop(); // dismiss dialog
                        context.go('/chats'); // route to chats
                      },
                    ),
                  ],
                );
              },
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),
                    // Top 1/3: Logo & Tagline (Spec 9.2)
                    Center(
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/images/logo_dark.png',
                            height: 90,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble,
                                    color: VybinTheme.whatsappTeal,
                                    size: 90,
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 10.0),
                                    child: Icon(
                                      Icons.lock,
                                      color: Colors.white,
                                      size: 36,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'VYBIN',
                            style: VybinTheme.headline1.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Private. Simple. Yours.',
                            style: VybinTheme.body2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 64),

                    // Middle: Input Fields
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !isLoading,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Email',
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: VybinTheme.secondaryText,
                        ),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !isLoading,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: VybinTheme.secondaryText,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: VybinTheme.secondaryText,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: _validatePassword,
                    ),

                    // Forgot Password Link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: isLoading
                            ? null
                            : () => context.push('/forgot-password'),
                        child: Text(
                          'Forgot Password?',
                          style: VybinTheme.caption.copyWith(
                            color: VybinTheme.whatsappTeal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Log In Button (Spec 9.2)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VybinTheme.whatsappGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      onPressed: isLoading ? null : _submitForm,
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Log In',
                              style: VybinTheme.subtitle1.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),

                    // Divider with "OR" (Spec 9.2)
                    const Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: VybinTheme.dividerCharcoal,
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: VybinTheme.secondaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: VybinTheme.dividerCharcoal,
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // "Create Account" link (centered, teal color) (Spec 9.2)
                    Center(
                      child: GestureDetector(
                        onTap: isLoading ? null : () => context.push('/signup'),
                        child: const Text(
                          'Create Account',
                          style: TextStyle(
                            color: VybinTheme.whatsappTeal,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Bottom encryption note
                    const Center(
                      child: Text(
                        'Your messages are end-to-end encrypted 🔒',
                        style: VybinTheme.caption,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
