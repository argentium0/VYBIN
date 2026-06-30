import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_state.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';

class OwnProfileScreen extends StatefulWidget {
  const OwnProfileScreen({super.key});

  @override
  State<OwnProfileScreen> createState() => _OwnProfileScreenState();
}

class _OwnProfileScreenState extends State<OwnProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _aboutController;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    String initialDisplayName = '';
    String initialAbout = '';

    if (authState is AuthAuthenticated) {
      initialDisplayName = authState.user.displayName;
      initialAbout = authState.user.about;
    }

    _displayNameController = TextEditingController(text: initialDisplayName);
    _aboutController = TextEditingController(text: initialAbout);

    _displayNameController.addListener(_checkForChanges);
    _aboutController.addListener(_checkForChanges);
  }

  @override
  void dispose() {
    _displayNameController.removeListener(_checkForChanges);
    _aboutController.removeListener(_checkForChanges);
    _displayNameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  void _checkForChanges() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final changed = _displayNameController.text != authState.user.displayName ||
          _aboutController.text != authState.user.about;
      if (changed != _hasChanges) {
        setState(() {
          _hasChanges = changed;
        });
      }
    }
  }

  void _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    // Simulate saving changes to profile
    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _hasChanges = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('Profile updated successfully'),
          ],
        ),
        backgroundColor: VybinTheme.whatsappGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VybinTheme.darkCharcoal,
      appBar: AppBar(
        backgroundColor: VybinTheme.whatsappDarkTeal,
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is! AuthAuthenticated) {
            return const Center(
              child: Text(
                'Please log in to view your profile.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final user = state.user;

          return SafeArea(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Large profile photo section with blurred background layout (Spec 9.7)
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: VybinTheme.whatsappDarkTeal.withOpacity(0.1),
                        border: const Border(
                          bottom: BorderSide(color: VybinTheme.dividerCharcoal),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: Container(
                              color: VybinTheme.whatsappTeal.withOpacity(0.05),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: VybinTheme.whatsappTeal,
                                child: Text(
                                  user.displayName.substring(0, 2).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Tap to change photo',
                                style: TextStyle(
                                  color: VybinTheme.whatsappGreen,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Display Name input (Editable)
                          TextFormField(
                            controller: _displayNameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Display Name',
                              prefixIcon: Icon(Icons.person_outline, color: VybinTheme.secondaryText),
                              suffixIcon: Icon(Icons.edit, color: VybinTheme.whatsappGreen, size: 20),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Display name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Username field (Read-only, lock icon)
                          TextFormField(
                            initialValue: '@${user.username}',
                            readOnly: true,
                            enabled: false,
                            style: const TextStyle(color: Colors.white70),
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.alternate_email_outlined, color: VybinTheme.secondaryText),
                              suffixIcon: Icon(Icons.lock_outline, color: VybinTheme.secondaryText, size: 20),
                              helperText: 'Username cannot be changed.',
                              helperStyle: TextStyle(color: VybinTheme.secondaryText),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // About Bio field (Editable, max 139 characters)
                          TextFormField(
                            controller: _aboutController,
                            style: const TextStyle(color: Colors.white),
                            maxLength: 139,
                            decoration: const InputDecoration(
                              labelText: 'About',
                              prefixIcon: Icon(Icons.info_outline, color: VybinTheme.secondaryText),
                              suffixIcon: Icon(Icons.edit, color: VybinTheme.whatsappGreen, size: 20),
                              counterStyle: TextStyle(color: VybinTheme.secondaryText),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Email field (Read-only, lock icon)
                          TextFormField(
                            initialValue: user.email,
                            readOnly: true,
                            enabled: false,
                            style: const TextStyle(color: Colors.white70),
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.mail_outline, color: VybinTheme.secondaryText),
                              suffixIcon: Icon(Icons.lock_outline, color: VybinTheme.secondaryText, size: 20),
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Save Changes button
                          ElevatedButton(
                            onPressed: (_hasChanges && !_isSaving) ? _saveChanges : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: VybinTheme.whatsappGreen,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[800],
                              disabledForegroundColor: Colors.grey[600],
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
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
