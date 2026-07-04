import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _pushNotifications = true;
  bool _inAppSounds = true;
  bool _vibration = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = prefs.getBool('push_notifications') ?? true;
      _inAppSounds = prefs.getBool('in_app_sounds') ?? true;
      _vibration = prefs.getBool('vibration') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _updateSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      if (key == 'push_notifications') _pushNotifications = value;
      if (key == 'in_app_sounds') _inAppSounds = value;
      if (key == 'vibration') _vibration = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                SwitchListTile(
                  secondary: Icon(Icons.notifications_active_outlined, color: theme.iconTheme.color),
                  title: Text('Push Notifications', style: TextStyle(color: onSurface)),
                  subtitle: const Text(
                    'Receive notifications for incoming messages',
                    style: TextStyle(color: VybinTheme.secondaryText, fontSize: 12),
                  ),
                  value: _pushNotifications,
                  activeThumbColor: VybinTheme.whatsappGreen,
                  onChanged: (val) => _updateSetting('push_notifications', val),
                ),
                const Divider(),
                SwitchListTile(
                  secondary: Icon(Icons.volume_up_outlined, color: theme.iconTheme.color),
                  title: Text('In-App Sounds', style: TextStyle(color: onSurface)),
                  subtitle: const Text(
                    'Play sound for sent and received messages when app is open',
                    style: TextStyle(color: VybinTheme.secondaryText, fontSize: 12),
                  ),
                  value: _inAppSounds,
                  activeThumbColor: VybinTheme.whatsappGreen,
                  onChanged: (val) => _updateSetting('in_app_sounds', val),
                ),
                const Divider(),
                SwitchListTile(
                  secondary: Icon(Icons.vibration_outlined, color: theme.iconTheme.color),
                  title: Text('Vibration', style: TextStyle(color: onSurface)),
                  subtitle: const Text(
                    'Vibrate on incoming message notification',
                    style: TextStyle(color: VybinTheme.secondaryText, fontSize: 12),
                  ),
                  value: _vibration,
                  activeThumbColor: VybinTheme.whatsappGreen,
                  onChanged: (val) => _updateSetting('vibration', val),
                ),
              ],
            ),
    );
  }
}
