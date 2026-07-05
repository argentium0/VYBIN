import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vybin/features/chat/data/chat_repository.dart';
import 'package:vybin/shared/models/user_model.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';

class KeyVerificationScreen extends StatefulWidget {
  final String conversationId;
  final String contactName;

  const KeyVerificationScreen({
    super.key,
    required this.conversationId,
    required this.contactName,
  });

  @override
  State<KeyVerificationScreen> createState() => _KeyVerificationScreenState();
}

class _KeyVerificationScreenState extends State<KeyVerificationScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  UserModel? _currentUser;
  UserModel? _recipientUser;

  String? _myFingerprint;
  String? _theirFingerprint;

  @override
  void initState() {
    super.initState();
    _fetchUsersAndCalculateFingerprints();
  }

  Future<void> _fetchUsersAndCalculateFingerprints() async {
    try {
      final chatRepo = context.read<ChatRepository>();
      final myUid = FirebaseAuth.instance.currentUser?.uid;
      if (myUid == null) {
        throw Exception('User is not authenticated');
      }

      final uids = widget.conversationId.split('_');
      final otherUid = uids.firstWhere((uid) => uid != myUid, orElse: () => '');

      if (otherUid.isEmpty) {
        throw Exception('Invalid conversation ID');
      }

      final currentUser = await chatRepo.getUserById(myUid);
      final recipientUser = await chatRepo.getUserById(otherUid);

      if (currentUser == null || recipientUser == null) {
        throw Exception('Failed to retrieve user profiles from database');
      }

      setState(() {
        _currentUser = currentUser;
        _recipientUser = recipientUser;
        _myFingerprint = _calculateFingerprint(currentUser.publicKey);
        _theirFingerprint = _calculateFingerprint(recipientUser.publicKey);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _calculateFingerprint(String publicKeyPem) {
    final bytes = utf8.encode(publicKeyPem.trim());
    final digest = sha256.convert(bytes);
    final hexString = digest.toString().toUpperCase();

    final List<String> blocks = [];
    for (int i = 0; i < 12; i++) {
      blocks.add(hexString.substring(i * 4, (i + 1) * 4));
    }
    return blocks.join('-');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: VybinTheme.darkCharcoal,
      appBar: AppBar(
        backgroundColor: VybinTheme.whatsappDarkTeal,
        title: const Text('Encryption Keys', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(onSurface),
    );
  }

  Widget _buildBody(Color onSurface) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: VybinTheme.neonHighlight,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: VybinTheme.errorColor, size: 60),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: onSurface, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Shield & Verification Title
            const Center(
              child: Icon(
                Icons.verified_user,
                color: VybinTheme.neonHighlight,
                size: 72,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Verify Security Code',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: onSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'To verify that your end-to-end encryption is secure and free from Man-In-The-Middle (MITM) intercepts, compare these fingerprints with the codes on your recipient\'s device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: VybinTheme.secondaryText,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),

            // Fingerprint grid for you
            _buildFingerprintCard(
              title: 'Your Fingerprint',
              subtitle: _currentUser!.displayName,
              fingerprint: _myFingerprint!,
            ),
            const SizedBox(height: 24),

            // Fingerprint grid for contact
            _buildFingerprintCard(
              title: '${widget.contactName}\'s Fingerprint',
              subtitle: '@${_recipientUser!.username}',
              fingerprint: _theirFingerprint!,
            ),
            const SizedBox(height: 32),

            // Informational Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: VybinTheme.whatsappDarkTeal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: VybinTheme.whatsappGreen.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    color: VybinTheme.neonHighlight,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'If these codes match the codes displayed on the other user\'s screen, your session is cryptographically validated as secure. Peer-to-peer encryption keys are generated on-device and never stored in raw form on any servers.',
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.9),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFingerprintCard({
    required String title,
    required String subtitle,
    required String fingerprint,
  }) {
    final blocks = fingerprint.split('-');

    return Card(
      color: VybinTheme.cardCharcoal,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: VybinTheme.dividerCharcoal),
      ),
      child: InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: fingerprint));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fingerprint copied to clipboard.'),
              backgroundColor: VybinTheme.whatsappGreen,
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: VybinTheme.neonHighlight,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.copy,
                    color: VybinTheme.neonHighlight,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // scannable visual grid of hash blocks
              LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: blocks.map((block) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: VybinTheme.darkCharcoal,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: VybinTheme.dividerCharcoal),
                        ),
                        child: Text(
                          block,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
