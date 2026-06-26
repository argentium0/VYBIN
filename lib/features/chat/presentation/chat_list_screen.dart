import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_event.dart';
import 'package:vybin/features/auth/bloc/auth_state.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';
import 'package:vybin/shared/models/user_model.dart';
import 'package:go_router/go_router.dart';

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

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
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
      avatarInitials: 'BD',
    ),
    MockChat(
      displayName: 'Hanzala Abid',
      username: 'charlie_b',
      lastMessage: '🔒 Let\'s verify our RSA public keys.',
      time: '2 days ago',
      unreadCount: 0,
      isRead: false,
      avatarInitials: 'CB',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuilds BottomNavigationBar and FAB visibility
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      backgroundColor: VybinTheme.darkCharcoal,
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
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search conversations...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                onChanged: (_) => setState(() {}),
              ),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: VybinTheme.whatsappGreen,
                labelColor: VybinTheme.whatsappGreen,
                unselectedLabelColor: VybinTheme.secondaryText,
                indicatorWeight: 3,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.chat_bubble_outline_outlined),
                    text: 'CHATS',
                  ),
                  Tab(icon: Icon(Icons.settings_outlined), text: 'SETTINGS'),
                ],
              ),
            )
          : AppBar(
              title: const Text('VYBIN'),
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
                      _tabController.animateTo(1);
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      const PopupMenuItem<String>(
                        value: 'settings',
                        child: Text(
                          'Settings',
                          style: TextStyle(color: Colors.white),
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
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: VybinTheme.whatsappGreen,
                labelColor: VybinTheme.whatsappGreen,
                unselectedLabelColor: VybinTheme.secondaryText,
                indicatorWeight: 3,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.chat_bubble_outline_outlined),
                    text: 'CHATS',
                  ),
                  Tab(icon: Icon(Icons.settings_outlined), text: 'SETTINGS'),
                ],
              ),
            ),
      drawer: Drawer(
        backgroundColor: VybinTheme.darkCharcoal,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: VybinTheme.whatsappDarkTeal,
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: VybinTheme.cardCharcoal,
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
              title: const Text(
                'E2EE Keys Setup',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'RSA-2048 Identity Cryptography Active',
                style: TextStyle(color: VybinTheme.secondaryText, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _tabController.animateTo(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text(
                'Dashboard Preferences',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _tabController.animateTo(1);
              },
            ),
            const Divider(color: VybinTheme.dividerCharcoal),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          // View 1: Chats Conversations list (Spec 9.4)
          filteredChats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: VybinTheme.cardCharcoal,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: VybinTheme.dividerCharcoal,
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
                      const Text(
                        'No conversations found',
                        style: VybinTheme.headline1,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Search or press the plus button to start a chat',
                        style: VybinTheme.body2,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: filteredChats.length,
                  separatorBuilder: (context, index) => const Divider(
                    color: VybinTheme.dividerCharcoal,
                    indent: 80,
                  ),
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
                        style: const TextStyle(
                          color: Colors.white,
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

          // View 2: User Settings / Profile panel (Spec 9.8)
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // User Profile Header
                Card(
                  color: VybinTheme.cardCharcoal,
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
                                style: const TextStyle(
                                  color: Colors.white,
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
                                style: const TextStyle(
                                  color: Colors.white70,
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
                            color: VybinTheme.inputCharcoal,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          height: 120,
                          child: SingleChildScrollView(
                            child: Text(
                              currentUser != null
                                  ? currentUser.publicKey
                                  : 'RSA Public Key details unavailable',
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
                const SizedBox(height: 16),

                // Settings lists
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: Colors.white),
                  title: const Text(
                    'Privacy',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Blocked contacts, last seen visibility',
                    style: TextStyle(
                      color: VybinTheme.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {},
                ),
                const Divider(color: VybinTheme.dividerCharcoal),
                ListTile(
                  leading: const Icon(
                    Icons.backup_outlined,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Chat Backup',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Local backup configuration',
                    style: TextStyle(
                      color: VybinTheme.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {},
                ),
                const Divider(color: VybinTheme.dividerCharcoal),
                ListTile(
                  leading: const Icon(
                    Icons.notifications_active_outlined,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Notifications',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Vibration, tones, indicators',
                    style: TextStyle(
                      color: VybinTheme.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {},
                ),
                const Divider(color: VybinTheme.dividerCharcoal),
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
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabController.index,
        onTap: (index) {
          _tabController.animateTo(index);
        },
        selectedItemColor: VybinTheme.whatsappGreen,
        unselectedItemColor: VybinTheme.secondaryText,
        backgroundColor: VybinTheme.cardCharcoal,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
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
