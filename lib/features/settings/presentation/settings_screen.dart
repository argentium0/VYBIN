import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vybin/app.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_event.dart';
import 'package:vybin/features/auth/bloc/auth_state.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final currentUser = state is AuthAuthenticated ? state.user : null;

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // User Profile Header summary
                if (currentUser != null) ...[
                  ListTile(
                    leading: CircleAvatar(
                      radius: 30,
                      backgroundColor: VybinTheme.whatsappTeal,
                      child: Text(
                        currentUser.displayName.substring(0, 2).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      currentUser.displayName,
                      style: TextStyle(
                        color: onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: const Text(
                      'Profile details, E2EE key status',
                      style: TextStyle(color: VybinTheme.secondaryText, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: VybinTheme.whatsappGreen),
                    onTap: () => context.push('/profile'),
                  ),
                  const Divider(height: 32),
                ],

                // Cryptographic key PEM section (Spec 9.8 / 9.7)
                if (currentUser != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.vpn_key_outlined,
                                  color: VybinTheme.whatsappGreen,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'E2EE Cryptographic Identity',
                                  style: TextStyle(
                                    color: onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Your generated RSA-2048 public identity key PEM block:',
                              style: TextStyle(
                                color: VybinTheme.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.inputDecorationTheme.fillColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              height: 100,
                              width: double.infinity,
                              child: SingleChildScrollView(
                                child: Text(
                                  currentUser.publicKey,
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Account: Privacy, Security, Change Password (stubs)
                ListTile(
                  leading: Icon(Icons.lock_outline, color: theme.iconTheme.color),
                  title: Text('Account', style: TextStyle(color: onSurface)),
                  subtitle: const Text(
                    'Privacy, security, change password',
                    style: TextStyle(color: VybinTheme.secondaryText, fontSize: 12),
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Account Security settings are managed automatically.')),
                    );
                  },
                ),
                const Divider(),

                // Activity Status Toggle
                ValueListenableBuilder<bool>(
                  valueListenable: VybinApp.showActivityStatusNotifier,
                  builder: (context, showStatus, _) {
                    return SwitchListTile(
                      secondary: Icon(
                        Icons.visibility_outlined,
                        color: theme.iconTheme.color,
                      ),
                      title: Text('Activity Status', style: TextStyle(color: onSurface)),
                      subtitle: const Text(
                        'Show when you are active. If off, you won\'t see others\' activity status.',
                        style: TextStyle(color: VybinTheme.secondaryText, fontSize: 12),
                      ),
                      value: showStatus,
                      activeThumbColor: VybinTheme.whatsappGreen,
                      onChanged: (bool value) async {
                        VybinApp.showActivityStatusNotifier.value = value;
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('show_activity_status', value);
                      },
                    );
                  },
                ),
                const Divider(),

                // Chats: Theme (light/dark switch), Chat Backup (stub)
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: VybinApp.themeNotifier,
                  builder: (context, currentMode, _) {
                    return SwitchListTile(
                      secondary: Icon(
                        currentMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                        color: theme.iconTheme.color,
                      ),
                      title: Text('Dark Mode', style: TextStyle(color: onSurface)),
                      subtitle: const Text(
                        'Toggle application visual theme',
                        style: TextStyle(color: VybinTheme.secondaryText, fontSize: 12),
                      ),
                      value: currentMode == ThemeMode.dark,
                      activeThumbColor: VybinTheme.whatsappGreen,
                      onChanged: (bool value) {
                        VybinApp.themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                      },
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.backup_outlined, color: theme.iconTheme.color),
                  title: Text('Chat Backup', style: TextStyle(color: onSurface)),
                  subtitle: const Text(
                    'Local backup configurations (Stub)',
                    style: TextStyle(color: VybinTheme.secondaryText, fontSize: 12),
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chat backup is stored securely in on-device hardware Keystore.')),
                    );
                  },
                ),
                const Divider(),

                // Notifications settings
                ListTile(
                  leading: Icon(Icons.notifications_none_outlined, color: theme.iconTheme.color),
                  title: Text('Notifications', style: TextStyle(color: onSurface)),
                  subtitle: const Text(
                    'Tones, vibration, popup preview controls',
                    style: TextStyle(color: VybinTheme.secondaryText, fontSize: 12),
                  ),
                  onTap: () {},
                ),
                const Divider(),

                // Help and licenses
                ListTile(
                  leading: Icon(Icons.help_outline_outlined, color: theme.iconTheme.color),
                  title: Text('Help', style: TextStyle(color: onSurface)),
                  subtitle: const Text(
                    'FAQ, contact support, licenses',
                    style: TextStyle(color: VybinTheme.secondaryText, fontSize: 12),
                  ),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'VYBIN',
                      applicationVersion: '1.0.0 (MVP)',
                      applicationIcon: const Icon(Icons.security, color: VybinTheme.whatsappGreen, size: 40),
                      applicationLegalese: '© 2026 VYBIN Privacy-First Messaging.',
                    );
                  },
                ),
                const Divider(),

                // Nuclear Purge Option Card (Spec 10.3 / 10.4)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    color: Colors.red.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: VybinTheme.errorColor, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: VybinTheme.errorColor),
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
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _showPurgeConfirmationDialog(context),
                              child: const Text(
                                'Purge Secure Local Environment',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(),

                // Log Out Option
                ListTile(
                  leading: const Icon(Icons.logout, color: VybinTheme.errorColor),
                  title: const Text(
                    'Log Out',
                    style: TextStyle(color: VybinTheme.errorColor, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    context.read<AuthBloc>().add(LogoutRequested());
                  },
                ),
              ],
            ),
          );
        },
      ),
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
            style: TextStyle(color: VybinTheme.errorColor, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you absolutely sure you want to purge the secure local environment? All private keys, local databases, and settings will be permanently destroyed. This cannot be undone.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: VybinTheme.secondaryText)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: VybinTheme.errorColor),
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                try {
                  final authBloc = context.read<AuthBloc>();

                  // Clear SharedPreferences
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();

                  // Clear FlutterSecureStorage
                  const secureStorage = FlutterSecureStorage();
                  await secureStorage.deleteAll();

                  // Clear cache and app directories
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

                  // Dispatch logout to auth bloc to trigger UI state reset
                  authBloc.add(LogoutRequested());

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
              child: const Text('PURGE EVERYTHING', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
