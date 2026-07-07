import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vybin/shared/models/user_model.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';
import 'package:vybin/shared/utils/contact_display_helper.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_state.dart';
import 'package:vybin/features/chat/data/chat_repository.dart';

class ContactProfileScreen extends StatefulWidget {
  final String userId;
  final String conversationId;

  const ContactProfileScreen({
    super.key,
    required this.userId,
    required this.conversationId,
  });

  @override
  State<ContactProfileScreen> createState() => _ContactProfileScreenState();
}

class _ContactProfileScreenState extends State<ContactProfileScreen> {
  final _nicknameController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadNickname();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadNickname() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedNickname = prefs.getString('contact_${widget.userId}');
    if (cachedNickname != null) {
      setState(() {
        _nicknameController.text = cachedNickname;
      });
    } else {
      // Check if there is a simulated alias fallback
      final simulatedAlias = localContactAliases[widget.userId];
      if (simulatedAlias != null) {
        setState(() {
          _nicknameController.text = simulatedAlias;
        });
      }
    }
  }

  Future<void> _saveNickname() async {
    setState(() {
      _isSaving = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final nickname = _nicknameController.text.trim();
      if (nickname.isEmpty) {
        await prefs.remove('contact_${widget.userId}');
      } else {
        await prefs.setString('contact_${widget.userId}', nickname);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Local nickname saved successfully.'),
            backgroundColor: VybinTheme.whatsappGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save nickname: $e'),
            backgroundColor: VybinTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _calculateFingerprint(String publicKeyPem) {
    if (publicKeyPem.isEmpty) return 'NO-KEY-REGISTERED';
    final bytes = utf8.encode(publicKeyPem.trim());
    final digest = sha256.convert(bytes);
    final hexString = digest.toString().toUpperCase();

    final List<String> blocks = [];
    for (int i = 0; i < 12; i++) {
      if ((i + 1) * 4 <= hexString.length) {
        blocks.add(hexString.substring(i * 4, (i + 1) * 4));
      }
    }
    return blocks.join('-');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.uid
        : '';

    return Scaffold(
      backgroundColor: VybinTheme.darkCharcoal,
      appBar: AppBar(
        backgroundColor: VybinTheme.whatsappDarkTeal,
        title: const Text(
          'Contact Info',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<UserModel?>(
        stream: context.read<ChatRepository>().getUserStream(
          widget.userId,
          currentUserId,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Error loading contact',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: VybinTheme.whatsappGreen),
            );
          }

          final user = snapshot.data!;
          final fingerprint = _calculateFingerprint(user.publicKey);

          // Initials for avatar
          final cleanName = user.displayName.isNotEmpty
              ? user.displayName
              : user.username;
          final initials = cleanName.length >= 2
              ? cleanName.substring(0, 2).toUpperCase()
              : cleanName.toUpperCase();

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 32),
                // Prominent Profile Picture Display
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 64,
                        backgroundColor: VybinTheme.whatsappTeal,
                        backgroundImage:
                            (user.profilePhotoUrl != null &&
                                user.profilePhotoUrl!.isNotEmpty)
                            ? NetworkImage(user.profilePhotoUrl!)
                            : null,
                        child:
                            (user.profilePhotoUrl == null ||
                                user.profilePhotoUrl!.isEmpty)
                            ? Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: VybinTheme.neonHighlight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shield,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Username Render
                Text(
                  '@${user.username}',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                // Display Name
                Text(
                  user.displayName.isNotEmpty
                      ? user.displayName
                      : 'No Display Name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),

                // Profile info card (Cyberpunk aesthetic)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: VybinTheme.cardCharcoal,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Local Customization',
                        style: TextStyle(
                          color: VybinTheme.whatsappGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Nickname Custom Field
                      TextFormField(
                        controller: _nicknameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Contact Nickname',
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintText: 'Set a local nickname',
                          hintStyle: const TextStyle(color: Colors.white30),
                          suffixIcon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: VybinTheme.whatsappGreen,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(
                                    Icons.check,
                                    color: VybinTheme.whatsappGreen,
                                  ),
                                  onPressed: _saveNickname,
                                ),
                        ),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _saveNickname(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // E2EE status & verification hash section
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: VybinTheme.cardCharcoal,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.lock,
                            color: VybinTheme.neonHighlight,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Security & Encryption',
                            style: TextStyle(
                              color: VybinTheme.neonHighlight,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Messages and calls in this chat are end-to-end encrypted. '
                        'To verify E2EE status out-of-band, compare this fingerprint hash with the contact:',
                        style: TextStyle(
                          color: VybinTheme.secondaryText,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Cryptographic Fingerprint block
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: fingerprint));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Fingerprint copied to clipboard.'),
                              backgroundColor: VybinTheme.whatsappGreen,
                            ),
                          );
                        },
                        child: Tooltip(
                          message: 'Tap to copy fingerprint',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(
                              fingerprint,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Colors.white,
                                fontSize: 14,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified,
                            color: VybinTheme.neonHighlight,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'RSA-OAEP SHA-256 Key fingerprint',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
