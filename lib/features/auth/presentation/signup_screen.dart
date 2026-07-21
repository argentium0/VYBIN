import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_event.dart';
import 'package:vybin/features/auth/bloc/auth_state.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedImagePath;
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  final _usernameFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Timer? _debounceTimer;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String _usernameFeedback = '';

  String _passwordStrength = 'None';

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
    _passwordController.addListener(_onPasswordChanged);
    _usernameFocusNode.addListener(_onUsernameFocusChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _usernameFocusNode.removeListener(_onUsernameFocusChanged);
    _usernameFocusNode.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onUsernameFocusChanged() {
    if (!_usernameFocusNode.hasFocus) {
      _checkUsernameAvailability(_usernameController.text.trim());
    }
  }

  void _onUsernameChanged() {
    final text = _usernameController.text.trim();
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    if (text.isEmpty) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = null;
        _usernameFeedback = '';
      });
      return;
    }

    final usernameRegex = RegExp(r'^[a-z0-9_]{3,20}$');
    if (!usernameRegex.hasMatch(text.toLowerCase())) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameFeedback = '✗ Alphanumeric, underscores, 3-20 chars only';
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameFeedback = 'Checking availability...';
    });

    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _checkUsernameAvailability(text);
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (username.isEmpty) return;

    final usernameRegex = RegExp(r'^[a-z0-9_]{3,20}$');
    if (!usernameRegex.hasMatch(username.toLowerCase())) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameFeedback = '✗ Alphanumeric, underscores, 3-20 chars only';
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameFeedback = 'Checking availability...';
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      _isCheckingUsername = false;
      if (username.toLowerCase() == 'taken') {
        _isUsernameAvailable = false;
        _usernameFeedback = '✗ Already taken';
      } else {
        _isUsernameAvailable = true;
        _usernameFeedback = '✓ Available';
      }
    });
  }

  void _onPasswordChanged() {
    final text = _passwordController.text;
    if (text.isEmpty) {
      setState(() {
        _passwordStrength = 'None';
      });
      return;
    }

    if (text.length < 6) {
      setState(() {
        _passwordStrength = 'Weak';
      });
    } else if (text.length < 8) {
      setState(() {
        _passwordStrength = 'Fair';
      });
    } else {
      final numRegex = RegExp(r'[0-9]');
      if (numRegex.hasMatch(text)) {
        setState(() {
          _passwordStrength = 'Strong';
        });
      } else {
        setState(() {
          _passwordStrength = 'Fair (Add a number for Strong)';
        });
      }
    }
  }

  String? _validateDisplayName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Display Name is required';
    }
    if (value.trim().length < 2 || value.trim().length > 50) {
      return 'Display name must be between 2 and 50 characters';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }
    final usernameRegex = RegExp(r'^[a-z0-9_]{3,20}$');
    if (!usernameRegex.hasMatch(value.trim().toLowerCase())) {
      return 'Invalid username format';
    }
    if (_isUsernameAvailable == false) {
      return 'Username is not available';
    }
    return null;
  }

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

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    final numRegex = RegExp(r'[0-9]');
    if (!numRegex.hasMatch(value)) {
      return 'Password must contain at least 1 number';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  void _submitForm() {
    if (_isUsernameAvailable == null &&
        _usernameController.text.trim().isNotEmpty) {
      _checkUsernameAvailability(_usernameController.text.trim()).then((_) {
        _performSignUpSubmit();
      });
    } else {
      _performSignUpSubmit();
    }
  }

  void _performSignUpSubmit() {
    if (_formKey.currentState!.validate() && _isUsernameAvailable == true) {
      context.read<AuthBloc>().add(
        SignUpRequested(
          displayName: _displayNameController.text.trim(),
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          localPhotoPath: _selectedImagePath,
        ),
      );
    }
  }

  Widget _buildPasswordStrengthBar() {
    double progress = 0.0;
    Color color = Colors.transparent;

    if (_passwordStrength == 'Weak') {
      progress = 0.33;
      color = VybinTheme.errorColor;
    } else if (_passwordStrength.startsWith('Fair')) {
      progress = 0.66;
      color = Colors.orange;
    } else if (_passwordStrength == 'Strong') {
      progress = 1.0;
      color = VybinTheme.whatsappGreen;
    }

    if (progress == 0.0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Strength: ',
                style: VybinTheme.caption.copyWith(
                  color: VybinTheme.secondaryText,
                ),
              ),
              Text(
                _passwordStrength,
                style: VybinTheme.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: VybinTheme.inputCharcoal,
              color: color,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VybinTheme.darkCharcoal,
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
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
          } else if (state is AuthNetworkError) {
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
          } else if (state is AuthEmailUnverified) {
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
                        Icons.vpn_key_outlined,
                        color: VybinTheme.whatsappGreen,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Account Created 🔑',
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
                        'Welcome to VYBIN, ${state.user.displayName}!',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'We have sent a verification email to:\n${state.user.email}\n\nPlease verify your email to access the app.\n\n'
                        'A cryptographically secure RSA-2048 public/private keypair has been generated on your device. '
                        'Your private key is encrypted and stored locally in your keystore, while your public key has been registered on the server.',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.85),
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
                      child: const Text('Verify Email'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.go('/verify-email');
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
                    const SizedBox(height: 16),

                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 45,
                              backgroundColor: VybinTheme.cardCharcoal,
                              backgroundImage: _selectedImagePath != null
                                  ? FileImage(File(_selectedImagePath!))
                                  : null,
                              child: _selectedImagePath == null
                                  ? Icon(
                                      Icons.person_outline,
                                      size: 48,

                                      color: VybinTheme.secondaryText
                                          .withOpacity(0.5),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: VybinTheme.whatsappGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_outlined,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    TextFormField(
                      controller: _displayNameController,
                      enabled: !isLoading,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Display Name',
                        prefixIcon: Icon(
                          Icons.badge_outlined,
                          color: VybinTheme.secondaryText,
                        ),
                      ),
                      validator: _validateDisplayName,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _usernameController,
                      focusNode: _usernameFocusNode,
                      enabled: !isLoading,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Username',
                        prefixIcon: const Icon(
                          Icons.alternate_email_outlined,
                          color: VybinTheme.secondaryText,
                        ),
                        prefixText: '@ ',
                        prefixStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        suffixIcon: _isCheckingUsername
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: VybinTheme.whatsappGreen,
                                  ),
                                ),
                              )
                            : (_isUsernameAvailable != null
                                  ? Icon(
                                      _isUsernameAvailable!
                                          ? Icons.check_circle
                                          : Icons.error_outline,
                                      color: _isUsernameAvailable!
                                          ? VybinTheme.whatsappGreen
                                          : VybinTheme.errorColor,
                                    )
                                  : null),
                      ),
                      validator: _validateUsername,
                    ),

                    if (_usernameFeedback.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          _usernameFeedback,
                          style: TextStyle(
                            fontSize: 12,
                            color: _isUsernameAvailable == true
                                ? VybinTheme.whatsappGreen
                                : (_isUsernameAvailable == false
                                      ? VybinTheme.errorColor
                                      : VybinTheme.secondaryText),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

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

                    _buildPasswordStrengthBar(),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      enabled: !isLoading,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Confirm Password',
                        prefixIcon: const Icon(
                          Icons.lock_reset_outlined,
                          color: VybinTheme.secondaryText,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: VybinTheme.secondaryText,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      validator: _validateConfirmPassword,
                    ),
                    const SizedBox(height: 32),

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
                              'Create Account',
                              style: VybinTheme.subtitle1.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),

                    Center(
                      child: GestureDetector(
                        onTap: isLoading ? null : () => context.pop(),
                        child: const Text(
                          'Already have an account? Log In',
                          style: TextStyle(
                            color: VybinTheme.whatsappTeal,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
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
