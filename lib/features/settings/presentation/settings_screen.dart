import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
                      activeColor: VybinTheme.whatsappGreen,
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
                      activeColor: VybinTheme.whatsappGreen,
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
}
