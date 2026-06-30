import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vybin/app.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_event.dart';
import 'package:vybin/features/auth/bloc/auth_state.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VybinTheme.darkCharcoal,
      appBar: AppBar(
        backgroundColor: VybinTheme.whatsappDarkTeal,
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      '@${currentUser.username}',
                      style: const TextStyle(color: VybinTheme.secondaryText),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: VybinTheme.whatsappGreen),
                    onTap: () => context.push('/profile'),
                  ),
                  const Divider(color: VybinTheme.dividerCharcoal, height: 32),
                ],

                // Cryptographic key PEM section (Spec 9.8 / 9.7)
                if (currentUser != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      color: VybinTheme.cardCharcoal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.vpn_key_outlined,
                                  color: VybinTheme.whatsappGreen,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'E2EE Cryptographic Identity',
                                  style: TextStyle(
                                    color: Colors.white,
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
                                color: Colors.grey[850],
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
                  leading: const Icon(Icons.lock_outline, color: Colors.white),
                  title: const Text('Account', style: TextStyle(color: Colors.white)),
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
                const Divider(color: VybinTheme.dividerCharcoal),

                // Chats: Theme (light/dark switch), Chat Backup (stub)
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: VybinApp.themeNotifier,
                  builder: (context, currentMode, _) {
                    return SwitchListTile(
                      secondary: Icon(
                        currentMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                        color: Colors.white,
                      ),
                      title: const Text('Dark Mode', style: TextStyle(color: Colors.white)),
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
                  leading: const Icon(Icons.backup_outlined, color: Colors.white),
                  title: const Text('Chat Backup', style: TextStyle(color: Colors.white)),
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
                const Divider(color: VybinTheme.dividerCharcoal),

                // Notifications settings
                ListTile(
                  leading: const Icon(Icons.notifications_none_outlined, color: Colors.white),
                  title: const Text('Notifications', style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                    'Tones, vibration, popup preview controls',
                    style: TextStyle(color: VybinTheme.secondaryText, fontSize: 12),
                  ),
                  onTap: () {},
                ),
                const Divider(color: VybinTheme.dividerCharcoal),

                // Help and licenses
                ListTile(
                  leading: const Icon(Icons.help_outline_outlined, color: Colors.white),
                  title: const Text('Help', style: TextStyle(color: Colors.white)),
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
                const Divider(color: VybinTheme.dividerCharcoal),

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
