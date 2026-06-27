import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_event.dart';
import 'package:vybin/features/auth/bloc/auth_state.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';
import 'package:vybin/shared/models/user_model.dart';
import 'package:go_router/go_router.dart';
import 'package:vybin/app.dart';

class MockChat {
  final String displayName;
  final String username;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isRead;
  final String avatarInitials;

  const MockChat({
    required this.displayName,
    required this.username,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isRead,
    required this.avatarInitials,
  });
}

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  final List<MockChat> _mockChats = const [
    MockChat(
      displayName: 'Abdulahad',
      username: 'alice_vybin',
      lastMessage: '🔒 Hey there! Did you get the key?',
      time: '10:35 AM',
      unreadCount: 2,
      isRead: false,
      avatarInitials: 'AC',
    ),
    MockChat(
      displayName: 'Bro',
      username: 'bob_d',
      lastMessage: '🔒 AES-GCM session key generated successfully.',
      time: 'Yesterday',
      unreadCount: 0,
      isRead: true,
      avatarInitials: 'BR',
    ),
    MockChat(
      displayName: 'Hanzala Abid',
      username: 'charlie_b',
      lastMessage: '🔒 Let\'s verify our RSA public keys.',
      time: '2 days ago',
      unreadCount: 0,
      isRead: false,
      avatarInitials: 'HA',
    ),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showNewChatSearchDialog(BuildContext context) {
    final searchInputController = TextEditingController();
    bool searchingUser = false;
    UserModel? foundUser;
    String searchFeedback = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: VybinTheme.cardCharcoal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'New Secure Chat',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Search for a user by their exact handle to initiate key encapsulation.',
                    style: TextStyle(
                      color: VybinTheme.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: searchInputController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Username',
                      prefixText: '@ ',
                      prefixStyle: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (searchFeedback.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      searchFeedback,
                      style: TextStyle(
                        color: foundUser != null
                            ? VybinTheme.whatsappGreen
                            : VybinTheme.errorColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  if (foundUser != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: VybinTheme.inputCharcoal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: VybinTheme.whatsappTeal,
                            child: Text(
                              foundUser!.displayName
                                  .substring(0, 2)
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  foundUser!.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '@${foundUser!.username}',
                                  style: const TextStyle(
                                    color: VybinTheme.secondaryText,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: VybinTheme.secondaryText),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                if (foundUser == null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VybinTheme.whatsappGreen,
                    ),
                    onPressed: searchingUser
                        ? null
                        : () async {
                            final text = searchInputController.text
                                .trim()
                                .toLowerCase();
                            if (text.isEmpty) return;

                            setDialogState(() {
                              searchingUser = true;
                              searchFeedback = 'Querying directory...';
                            });

                            await Future.delayed(
                              const Duration(milliseconds: 600),
                            );

                            setDialogState(() {
                              searchingUser = false;
                              if (text == 'taken' ||
                                  text == 'alice_vybin' ||
                                  text == 'bob_d') {
                                foundUser = UserModel(
                                  uid: 'mock_searched_123',
                                  username: text,
                                  displayName: text == 'bob_d'
                                      ? 'Bob Dylan'
                                      : 'Alice Cooper',
                                  email: '$text@example.com',
                                  profilePhotoUrl: null,
                                  publicKey:
                                      '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgK...',
                                  fcmToken: 'token',
                                  onlineStatus: 'online',
                                  lastSeen: DateTime.now(),
                                  about: 'Hey there! I am using VYBIN',
                                  createdAt: DateTime.now(),
                                  blockedUids: const [],
                                );
                                searchFeedback = '✓ Secure Identity Verified';
                              } else {
                                foundUser = null;
                                searchFeedback = '✗ Username not found';
                              }
                            });
                          },
                    child: searchingUser
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Search',
                            style: TextStyle(color: Colors.white),
                          ),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VybinTheme.whatsappGreen,
                    ),
                    child: const Text(
                      'Message (E2EE)',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '🔒 Initiating end-to-end encrypted session with @${foundUser!.username}',
                          ),
                          backgroundColor: VybinTheme.whatsappTeal,
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildChatsView(List<MockChat> filteredChats) {
    if (filteredChats.isEmpty) {
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
                  color:
                      Theme.of(context).dividerTheme.color ??
                      VybinTheme.dividerCharcoal,
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
              'Search or press the plus button to start a chat',
              style: VybinTheme.body2,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: filteredChats.length,
            separatorBuilder: (context, index) =>
                const Divider(color: VybinTheme.dividerCharcoal, indent: 80),
            itemBuilder: (context, index) {
              final chat = filteredChats[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: VybinTheme.whatsappTeal,
                  child: Text(
                    chat.avatarInitials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                title: Text(
                  chat.displayName,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    chat.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: VybinTheme.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      chat.time,
                      style: TextStyle(
                        color: chat.unreadCount > 0
                            ? VybinTheme.whatsappGreen
                            : VybinTheme.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (chat.unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: VybinTheme.whatsappGreen,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${chat.unreadCount}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (chat.isRead)
                      const Icon(
                        Icons.done_all,
                        color: VybinTheme.neonBlue,
                        size: 16,
                      )
                    else
                      const Icon(
                        Icons.done,
                        color: VybinTheme.secondaryText,
                        size: 16,
                      ),
                  ],
                ),
                onTap: () {
                  context.push(
                    '/chat/${chat.username}',
                    extra: {
                      'contactName': chat.displayName,
                      'contactAvatarInitials': chat.avatarInitials,
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsView(UserModel? currentUser) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User Profile Header
          Card(
            color: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: VybinTheme.whatsappTeal,
                    child: Text(
                      currentUser != null
                          ? currentUser.displayName
                                .substring(0, 2)
                                .toUpperCase()
                          : 'G',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUser != null
                              ? currentUser.displayName
                              : 'Guest User',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentUser != null
                              ? '@${currentUser.username}'
                              : '@guest',
                          style: const TextStyle(
                            color: VybinTheme.secondaryText,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentUser != null
                              ? currentUser.about
                              : 'Hey there! I am using VYBIN',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Encryption Keys Details Section
          Card(
            color: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
                          color: Theme.of(context).colorScheme.onSurface,
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
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    height: 120,
                    child: SingleChildScrollView(
                      child: Text(
                        currentUser != null
                            ? currentUser.publicKey
                            : 'RSA Public Key details unavailable',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.greenAccent
                              : Colors.green[900],
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
          const SizedBox(height: 16),

          // Settings lists
          ListTile(
            leading: Icon(
              Icons.lock_outline,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            title: Text(
              'Privacy',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            subtitle: const Text(
              'Blocked contacts, last seen visibility',
              style: TextStyle(color: VybinTheme.secondaryText, fontSize: 12),
            ),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.backup_outlined,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            title: Text(
              'Chat Backup',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            subtitle: const Text(
              'Local backup configuration',
              style: TextStyle(color: VybinTheme.secondaryText, fontSize: 12),
            ),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.notifications_active_outlined,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            title: Text(
              'Notifications',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            subtitle: const Text(
              'Vibration, tones, indicators',
              style: TextStyle(color: VybinTheme.secondaryText, fontSize: 12),
            ),
            onTap: () {},
          ),
          const Divider(),

          // Dark Mode Toggle Switch Tile
          ValueListenableBuilder<ThemeMode>(
            valueListenable: VybinApp.themeNotifier,
            builder: (context, currentMode, _) {
              return ListTile(
                leading: Icon(
                  currentMode == ThemeMode.dark
                      ? Icons.dark_mode
                      : Icons.light_mode,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                title: Text(
                  'Dark Mode',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle: const Text(
                  'Toggle between light and dark themes',
                  style: TextStyle(
                    color: VybinTheme.secondaryText,
                    fontSize: 12,
                  ),
                ),
                trailing: Switch(
                  value: currentMode == ThemeMode.dark,
                  activeColor: VybinTheme.whatsappGreen,
                  onChanged: (bool value) {
                    VybinApp.themeNotifier.value = value
                        ? ThemeMode.dark
                        : ThemeMode.light;
                  },
                ),
              );
            },
          ),
          const Divider(),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: VybinTheme.errorColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Log Out Account',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              context.read<AuthBloc>().add(LogoutRequested());
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    UserModel? currentUser;
    if (authState is AuthAuthenticated) {
      currentUser = authState.user;
    }

    // Dynamic filtering for chats search
    final filteredChats = _mockChats.where((chat) {
      if (!_isSearching) return true;
      final query = _searchController.text.toLowerCase();
      return chat.displayName.toLowerCase().contains(query) ||
          chat.username.toLowerCase().contains(query);
    }).toList();

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
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
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
                      setState(() {
                        _currentIndex = 1;
                      });
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
            UserAccountsDrawerHeader(
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
                setState(() {
                  _currentIndex = 1;
                });
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
                setState(() {
                  _currentIndex = 1;
                });
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
      body: Column(
        children: [
          Expanded(
            child: _currentIndex == 0
                ? _buildChatsView(filteredChats)
                : _buildSettingsView(currentUser),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
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
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              backgroundColor: VybinTheme.whatsappGreen,
              foregroundColor: Colors.white,
              onPressed: () => _showNewChatSearchDialog(context),
              child: const Icon(Icons.chat_outlined),
            )
          : null,
    );
  }
}
