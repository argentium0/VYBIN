import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_event.dart';
import 'package:vybin/features/auth/bloc/auth_state.dart';
import 'package:vybin/features/chat/bloc/chat_list_bloc.dart';
import 'package:vybin/features/chat/bloc/chat_list_event.dart';
import 'package:vybin/features/chat/bloc/chat_list_state.dart';
import 'package:vybin/shared/models/conversation_model.dart';
import 'package:vybin/shared/models/user_model.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';

class ContactDetails {
  final String displayName;
  final String avatarInitials;
  final String username;
  const ContactDetails(this.displayName, this.avatarInitials, this.username);
}

ContactDetails getContactDetails(String conversationId) {
  if (conversationId == 'alice_vybin') {
    return const ContactDetails('Abdulahad', 'AC', 'alice_vybin');
  } else if (conversationId == 'bob_d') {
    return const ContactDetails('Bro', 'BR', 'bob_d');
  } else if (conversationId == 'charlie_b') {
    return const ContactDetails('Hanzala Abid', 'HA', 'charlie_b');
  }
  final initials = conversationId.length >= 2
      ? conversationId.substring(0, 2).toUpperCase()
      : conversationId.toUpperCase();
  return ContactDetails(conversationId, initials, conversationId);
}

String formatMessageTime(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);
  if (diff.inDays == 0 && now.day == dateTime.day) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  } else if (diff.inDays == 1 || (diff.inDays == 0 && now.day != dateTime.day)) {
    return 'Yesterday';
  } else {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildChatsView(List<ConversationModel> conversations) {
    final filteredConversations = conversations.where((conv) {
      if (!_isSearching) return true;
      final query = _searchController.text.toLowerCase();
      final contact = getContactDetails(conv.conversationId);
      return contact.displayName.toLowerCase().contains(query) ||
          contact.username.toLowerCase().contains(query);
    }).toList();

    if (filteredConversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).dividerTheme.color ?? VybinTheme.dividerCharcoal,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 64,
                color: VybinTheme.whatsappGreen,
              ),
            ),
            const SizedBox(height: 24),
            const Text('No conversations found', style: VybinTheme.headline1),
            const SizedBox(height: 8),
            const Text(
              'Search or press the button to start a chat',
              style: VybinTheme.body2,
            ),
          ],
        ),
      );
    }

    final authState = context.read<AuthBloc>().state;
    final myUid = authState is AuthAuthenticated ? authState.user.uid : 'my_uid_123';

    return ListView.separated(
      itemCount: filteredConversations.length,
      separatorBuilder: (context, index) =>
          const Divider(color: VybinTheme.dividerCharcoal, indent: 80),
      itemBuilder: (context, index) {
        final conv = filteredConversations[index];
        final contact = getContactDetails(conv.conversationId);
        final unread = conv.unreadCount[myUid] ?? 0;
        final hasLastMessage = conv.lastMessagePreview != null;
        final lastMessageText = hasLastMessage ? conv.lastMessagePreview!.ciphertext : '';
        final isSentByMe = hasLastMessage && conv.lastMessagePreview!.senderUid == myUid;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: VybinTheme.whatsappTeal,
            child: Text(
              contact.avatarInitials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          title: Text(
            contact.displayName,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              lastMessageText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: VybinTheme.secondaryText,
                fontSize: 14,
              ),
            ),
          ),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMessageTime(conv.lastMessageAt),
                style: TextStyle(
                  color: unread > 0 ? VybinTheme.whatsappGreen : VybinTheme.secondaryText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: const BoxDecoration(
                    color: VybinTheme.whatsappGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$unread',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (isSentByMe)
                const Icon(
                  Icons.done_all,
                  color: VybinTheme.neonBlue,
                  size: 16,
                ),
            ],
          ),
          onTap: () {
            context.push(
              '/chat/${contact.username}',
              extra: {
                'contactName': contact.displayName,
                'contactAvatarInitials': contact.avatarInitials,
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    UserModel? currentUser;
    if (authState is AuthAuthenticated) {
      currentUser = authState.user;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _isSearching
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                  });
                },
              ),
              title: TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                onChanged: (_) => setState(() {}),
              ),
            )
          : AppBar(
              centerTitle: false,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32.0,
                    height: 32.0,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    clipBehavior: Clip.hardEdge,
                    child: Image.asset(
                      Theme.of(context).brightness == Brightness.dark
                          ? 'assets/images/logo_dark.png'
                          : 'assets/images/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'VYBIN',
                    style: TextStyle(
                      fontFamily: 'System',
                      fontWeight: FontWeight.w900,
                      fontSize: 24.0,
                      letterSpacing: 1.5,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF075E54),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'logout') {
                      context.read<AuthBloc>().add(LogoutRequested());
                    } else if (value == 'settings') {
                      context.push('/settings');
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      PopupMenuItem<String>(
                        value: 'settings',
                        child: Text(
                          'Settings',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'logout',
                        child: Text(
                          'Log Out',
                          style: TextStyle(color: VybinTheme.errorColor),
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
      drawer: Drawer(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                context.push('/profile');
              },
              child: UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  color: VybinTheme.whatsappDarkTeal,
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  child: Text(
                    currentUser != null
                        ? currentUser.displayName.substring(0, 2).toUpperCase()
                        : 'VY',
                    style: const TextStyle(
                      color: VybinTheme.whatsappGreen,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                accountName: Text(
                  currentUser != null ? currentUser.displayName : 'Guest User',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                accountEmail: Text(
                  currentUser != null ? '@${currentUser.username}' : '@guest',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.security,
                color: VybinTheme.whatsappGreen,
              ),
              title: Text(
                'E2EE Keys Setup',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: const Text(
                'RSA-2048 Identity Cryptography Active',
                style: TextStyle(color: VybinTheme.secondaryText, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
            ListTile(
              leading: Icon(
                Icons.settings,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              title: Text(
                'Dashboard Preferences',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: VybinTheme.errorColor),
              title: const Text(
                'Log Out',
                style: TextStyle(color: VybinTheme.errorColor),
              ),
              onTap: () {
                Navigator.pop(context);
                context.read<AuthBloc>().add(LogoutRequested());
              },
            ),
          ],
        ),
      ),
      body: BlocBuilder<ChatListBloc, ChatListState>(
        builder: (context, state) {
          if (state is ChatListLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: VybinTheme.whatsappGreen,
              ),
            );
          } else if (state is ChatListError) {
            return Center(
              child: Text(
                state.errorMessage,
                style: const TextStyle(color: VybinTheme.errorColor, fontSize: 16),
              ),
            );
          } else if (state is ChatListLoaded) {
            return _buildChatsView(state.conversations);
          }
          return const SizedBox.shrink();
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            context.push('/settings');
          }
        },
        selectedItemColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF00FFCC)
            : VybinTheme.whatsappTeal,
        unselectedItemColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey
            : Colors.grey[600],
        backgroundColor: Theme.of(context).colorScheme.surface,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: VybinTheme.whatsappGreen,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/new-chat'),
        child: const Icon(Icons.chat_outlined),
      ),
    );
  }
}
