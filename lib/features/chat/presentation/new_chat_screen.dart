import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_state.dart';
import 'package:vybin/features/chat/data/chat_repository.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';
import 'package:vybin/shared/models/user_model.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _searchInputController = TextEditingController();
  bool _searchingUser = false;
  UserModel? _foundUser;
  String _searchFeedback = '';

  @override
  void dispose() {
    _searchInputController.dispose();
    super.dispose();
  }

  void _searchUser() async {
    final text = _searchInputController.text.trim().toLowerCase();
    if (text.isEmpty) return;

    setState(() {
      _searchingUser = true;
      _searchFeedback = 'Querying cryptographic directory...';
      _foundUser = null;
    });

    try {
      final chatRepo = context.read<ChatRepository>();
      final user = await chatRepo.searchUserByUsername(text);

      if (!mounted) return;

      setState(() {
        _searchingUser = false;
        if (user != null) {
          _foundUser = user;
          _searchFeedback = 'User found in directory!';
        } else {
          _foundUser = null;
          _searchFeedback = 'No cryptographic identity found for @$text';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchingUser = false;
        _foundUser = null;
        _searchFeedback = 'Error searching directory: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VybinTheme.darkCharcoal,
      appBar: AppBar(
        backgroundColor: VybinTheme.whatsappDarkTeal,
        title: const Text('New Secure Chat', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Search for a user by their exact handle to initiate key encapsulation.',
                style: TextStyle(
                  color: VybinTheme.secondaryText,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchInputController,
                      style: const TextStyle(color: Colors.white),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchUser(),
                      decoration: const InputDecoration(
                        hintText: 'Username',
                        prefixText: '@ ',
                        prefixStyle: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: VybinTheme.whatsappGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                    ),
                    icon: const Icon(Icons.search),
                    onPressed: _searchUser,
                  ),
                ],
              ),
              if (_searchFeedback.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _searchFeedback,
                  style: TextStyle(
                    color: _foundUser != null
                        ? VybinTheme.whatsappGreen
                        : (_searchingUser ? Colors.white70 : VybinTheme.errorColor),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              if (_foundUser != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: VybinTheme.cardCharcoal,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: VybinTheme.whatsappGreen.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: VybinTheme.whatsappTeal,
                            child: Text(
                              _foundUser!.displayName.substring(0, 2).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _foundUser!.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '@${_foundUser!.username}',
                                  style: const TextStyle(
                                    color: VybinTheme.secondaryText,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'About: ${_foundUser!.about}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VybinTheme.whatsappGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          final authState = context.read<AuthBloc>().state;
                          if (authState is AuthAuthenticated) {
                            final myUid = authState.user.uid;
                            final otherUid = _foundUser!.uid;
                            final chatRepo = context.read<ChatRepository>();

                            final conversationId = chatRepo.generateConversationId(myUid, otherUid);
                            
                            await chatRepo.createConversation(
                              conversationId: conversationId,
                              participantUids: [myUid, otherUid],
                            );

                            if (context.mounted) {
                              context.pop(); // Close search page
                              context.push(
                                '/chat/$conversationId',
                                extra: {
                                  'contactName': _foundUser!.displayName,
                                  'contactAvatarInitials': _foundUser!.displayName.substring(0, 2).toUpperCase(),
                                },
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('You must be logged in to start a conversation.')),
                            );
                          }
                        },
                        child: const Text(
                          'Message',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
  }
}
