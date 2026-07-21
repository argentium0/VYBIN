import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_event.dart';
import 'package:vybin/features/auth/bloc/auth_state.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';
import 'package:vybin/core/services/secure_key_storage.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Account')),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthUnauthenticated) {
            context.go('/login');
          } else if (state is AuthPasswordChangeSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Password successfully changed and cryptographic vault re-encrypted! 🔑',
                ),
                backgroundColor: VybinTheme.whatsappGreen,
              ),
            );
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: VybinTheme.errorColor,
              ),
            );
          } else if (state is AuthNetworkError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: VybinTheme.errorColor,
              ),
            );
          }
        },
        builder: (context, state) {
          final email = state is AuthAuthenticated ? state.user.email : '';
          final isLoading = state is AuthLoading;

          return isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.lock_reset_outlined,
                        color: theme.iconTheme.color,
                      ),
                      title: Text(
                        'Change Password',
                        style: TextStyle(color: onSurface),
                      ),
                      subtitle: const Text(
                        'Change your password and re-encrypt E2EE keys',
                        style: TextStyle(
                          color: VybinTheme.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        if (email.isEmpty) return;
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (dialogContext) => BlocProvider.value(
                            value: context.read<AuthBloc>(),
                            child: const _ChangePasswordDialog(),
                          ),
                        );
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: Icon(
                        Icons.lock_outline,
                        color: theme.iconTheme.color,
                      ),
                      title: Text(
                        'Export Cryptographic Identity',
                        style: TextStyle(color: onSurface),
                      ),
                      subtitle: const Text(
                        'Export secure E2EE keys for device migration',
                        style: TextStyle(
                          color: VybinTheme.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () => _handleExportIdentity(context),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(
                        Icons.delete_forever_outlined,
                        color: VybinTheme.errorColor,
                      ),
                      title: const Text(
                        'Delete Account',
                        style: TextStyle(
                          color: VybinTheme.errorColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Erase user data and permanently delete profile',
                        style: TextStyle(
                          color: VybinTheme.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () => _showDeleteConfirmation(context),
                    ),
                    const Divider(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Card(
                        color: Colors.red.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: VybinTheme.errorColor,
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: VybinTheme.errorColor,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'DANGER ZONE',
                                    style: TextStyle(
                                      color: VybinTheme.errorColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Purging the secure local environment will erase all local databases, SQLite/Hive caches, settings, and completely delete your local RSA private keys from the device secure storage.\n\nThis action is irreversible and your message history will be permanently lost.',
                                style: TextStyle(
                                  color: onSurface.withValues(alpha: 0.9),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: VybinTheme.errorColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _showPurgeConfirmationDialog(context),
                                  child: const Text(
                                    'Purge Secure Local Environment',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: VybinTheme.cardCharcoal,
          title: const Text(
            'Delete Account?',
            style: TextStyle(
              color: VybinTheme.errorColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Are you sure you want to permanently delete your account? This will erase all your messages, profile details, and private keys. This action cannot be undone.\n\nNote: If you logged in a long time ago, you may need to re-authenticate first.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: VybinTheme.secondaryText),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: VybinTheme.errorColor,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<AuthBloc>().add(DeleteAccountRequested());
              },
              child: const Text(
                'DELETE ACCOUNT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPurgeConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: VybinTheme.cardCharcoal,
          title: const Text(
            'Confirm Nuclear Purge',
            style: TextStyle(
              color: VybinTheme.errorColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Are you absolutely sure you want to purge the secure local environment? All private keys, local databases, and settings will be permanently destroyed. This cannot be undone.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: VybinTheme.secondaryText),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: VybinTheme.errorColor,
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                try {
                  final authBloc = context.read<AuthBloc>();

                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();

                  const secureStorage = FlutterSecureStorage();
                  await secureStorage.deleteAll();

                  final appDir = await getApplicationSupportDirectory();
                  final cacheDir = await getTemporaryDirectory();
                  final docDir = await getApplicationDocumentsDirectory();

                  final directories = [appDir, cacheDir, docDir];
                  for (final dir in directories) {
                    if (await dir.exists()) {
                      try {
                        await dir.delete(recursive: true);
                      } catch (_) {}
                    }
                  }

                  authBloc.add(const LogoutRequested(eraseDeviceData: true));

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Local environment successfully purged.'),
                        backgroundColor: VybinTheme.whatsappGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Purge failed: $e'),
                        backgroundColor: VybinTheme.errorColor,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'PURGE EVERYTHING',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleExportIdentity(BuildContext context) async {
    try {
      final secureStorage = SecureKeyStorage();
      final encryptedKey = await secureStorage.readEncryptedPrivateKey();

      if (!context.mounted) return;

      if (encryptedKey == null || encryptedKey.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No cryptographic identity found on this device.'),
            backgroundColor: VybinTheme.errorColor,
          ),
        );
        return;
      }

      _showExportIdentityDialog(context, encryptedKey);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error retrieving identity: $e'),
            backgroundColor: VybinTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showExportIdentityDialog(BuildContext context, String encryptedKey) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: VybinTheme.cardCharcoal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.security, color: VybinTheme.whatsappGreen),
              const SizedBox(width: 8),
              Text(
                'Cryptographic Identity',
                style: TextStyle(
                  color: onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: Colors.amber.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.amber, width: 1),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.amber,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'WARNING',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Keep this secure. You will need this string to restore your chat history on a new device. Do not alter the text.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Encrypted Private Key Blob:',
                    style: TextStyle(
                      color: VybinTheme.secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 120,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: VybinTheme.inputCharcoal,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: VybinTheme.dividerCharcoal),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        encryptedKey,
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VybinTheme.whatsappTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.copy_all),
                    label: const Text(
                      'Copy to Clipboard',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: encryptedKey),
                      );
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('has_exported_identity', true);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Identity copied. Save this blob somewhere safe, like a password manager.',
                            ),
                            backgroundColor: VybinTheme.whatsappGreen,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: VybinTheme.secondaryText),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Current password is required';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'New password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(value);
    final hasNumber = RegExp(r'\d').hasMatch(value);
    if (!hasLetter || !hasNumber) {
      return 'Password must contain at least one letter and one number';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your new password';
    }
    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthPasswordChangeSuccess) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return AlertDialog(
          backgroundColor: VybinTheme.cardCharcoal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.lock_outline, color: VybinTheme.whatsappGreen),
              const SizedBox(width: 8),
              Text(
                'Change Password',
                style: TextStyle(
                  color: onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'This updates your Firebase password and re-encrypts your local cryptographic vault keys.',
                      style: TextStyle(
                        color: VybinTheme.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: _obscureCurrent,
                      enabled: !isLoading,
                      style: TextStyle(color: onSurface),
                      decoration: InputDecoration(
                        hintText: 'Current Password',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: VybinTheme.secondaryText,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureCurrent
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: VybinTheme.secondaryText,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureCurrent = !_obscureCurrent;
                            });
                          },
                        ),
                      ),
                      validator: _validateCurrentPassword,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      enabled: !isLoading,
                      style: TextStyle(color: onSurface),
                      decoration: InputDecoration(
                        hintText: 'New Password',
                        prefixIcon: const Icon(
                          Icons.lock_open_outlined,
                          color: VybinTheme.secondaryText,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNew
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: VybinTheme.secondaryText,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureNew = !_obscureNew;
                            });
                          },
                        ),
                      ),
                      validator: _validateNewPassword,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      enabled: !isLoading,
                      style: TextStyle(color: onSurface),
                      decoration: InputDecoration(
                        hintText: 'Confirm New Password',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: VybinTheme.secondaryText,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: VybinTheme.secondaryText,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirm = !_obscureConfirm;
                            });
                          },
                        ),
                      ),
                      validator: _validateConfirmPassword,
                    ),
                    if (isLoading) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(
                        color: VybinTheme.whatsappGreen,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: VybinTheme.secondaryText),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: VybinTheme.whatsappGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: isLoading
                  ? null
                  : () {
                      if (_formKey.currentState?.validate() ?? false) {
                        context.read<AuthBloc>().add(
                          ChangePasswordRequested(
                            currentPassword: _currentPasswordController.text,
                            newPassword: _newPasswordController.text,
                          ),
                        );
                      }
                    },
              child: const Text(
                'Change Password',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
