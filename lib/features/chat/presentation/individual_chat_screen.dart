import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../shared/theme/vybin_theme.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../models/message.dart';

class IndividualChatScreen extends StatefulWidget {
  final String conversationId;
  final String contactName;
  final String contactAvatarInitials;

  const IndividualChatScreen({
    super.key,
    required this.conversationId,
    required this.contactName,
    required this.contactAvatarInitials,
  });

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> with SingleTickerProviderStateMixin {
  late ChatBloc _chatBloc;
  final TextEditingController _messageController = TextEditingController();

  // Temporary hardcoded sender UID for MVP
  final String _currentUserId = 'my_uid_123';

  // Audio recording local states
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  bool _isTextEmpty = true;

  late AnimationController _micAnimationController;
  late Animation<double> _micAnimationScale;

  @override
  void initState() {
    super.initState();
    _chatBloc = ChatBloc()..add(LoadMessages(widget.conversationId));
    _messageController.addListener(_onTextChanged);

    _micAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _micAnimationScale = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _micAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _micAnimationController.dispose();
    _recordingTimer?.cancel();
    _chatBloc.close();
    super.dispose();
  }

  void _onTextChanged() {
    final empty = _messageController.text.trim().isEmpty;
    if (empty != _isTextEmpty) {
      setState(() {
        _isTextEmpty = empty;
      });
    }
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordingDuration = 0;
    });
    _micAnimationController.repeat(reverse: true);
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration++;
      });
    });
  }

  void _stopRecording() {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _micAnimationController.stop();
    _micAnimationController.reset();

    final finalDuration = _recordingDuration > 0 ? _recordingDuration : 1;
    final durationString = _formatDuration(finalDuration);

    setState(() {
      _isRecording = false;
    });

    // Generate mock message with voice type
    _chatBloc.add(SendMessage(
      plaintext: 'Voice Message ($durationString)',
      type: 'voice',
      senderUid: _currentUserId,
    ));
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _extractDuration(String plaintext) {
    final start = plaintext.indexOf('(');
    final end = plaintext.indexOf(')');
    if (start != -1 && end != -1 && end > start) {
      return plaintext.substring(start + 1, end);
    }
    return '0:00';
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      _chatBloc.add(SendMessage(
        plaintext: text,
        type: 'text',
        senderUid: _currentUserId,
      ));
      _messageController.clear();
    }
  }

  void _showMediaBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: VybinTheme.cardCharcoal,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMediaOption(
                icon: Icons.camera_alt,
                color: Colors.pink,
                label: 'Camera',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement camera logic
                },
              ),
              _buildMediaOption(
                icon: Icons.mic,
                color: VybinTheme.whatsappTeal,
                label: 'Audio',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement audio logic
                },
              ),
              _buildMediaOption(
                icon: Icons.insert_drive_file,
                color: Colors.deepPurpleAccent,
                label: 'Document',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement document logic
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: VybinTheme.body2),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _chatBloc,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: VybinTheme.whatsappTeal,
                child: Text(
                  widget.contactAvatarInitials,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.contactName, style: VybinTheme.headline1.copyWith(fontSize: 18)),
                  Text('online', style: VybinTheme.caption.copyWith(color: VybinTheme.whatsappGreen)),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: BlocBuilder<ChatBloc, ChatState>(
                builder: (context, state) {
                  if (state is ChatLoading) {
                    return const Center(child: CircularProgressIndicator(color: VybinTheme.neonHighlight));
                  } else if (state is ChatLoaded) {
                    final messages = state.messages;
                    if (messages.isEmpty) {
                      return Center(
                        child: Text(
                          'Messages are end-to-end encrypted.\nNo one outside of this chat can read them 🔒',
                          textAlign: TextAlign.center,
                          style: VybinTheme.caption,
                        ),
                      );
                    }
                    return ListView.builder(
                      reverse: true, // Scroll from bottom to top
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderUid == _currentUserId;
                        return _buildChatBubble(message, isMe);
                      },
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            _buildInputZone(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(Message message, bool isMe) {
    if (message.type == 'voice') {
      return _buildVoiceBubble(message, isMe);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? VybinTheme.sentBubbleColor : VybinTheme.receivedBubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomLeft: Radius.circular(isMe ? 8 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 8),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x21000000),
              blurRadius: 1,
              offset: Offset(0, 1),
            )
          ],
        ),
        child: Text(
          message.plaintext ?? '',
          style: VybinTheme.messageText,
        ),
      ),
    );
  }

  Widget _buildVoiceBubble(Message message, bool isMe) {
    final durationText = _extractDuration(message.plaintext ?? 'Voice Message (0:00)');
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMe ? VybinTheme.sentBubbleColor : VybinTheme.receivedBubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 12),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x21000000),
              blurRadius: 1,
              offset: Offset(0, 1),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isMe ? Colors.white.withValues(alpha: 0.2) : VybinTheme.whatsappTeal.withValues(alpha: 0.2),
              child: Icon(
                Icons.play_arrow_rounded,
                color: isMe ? Colors.white : VybinTheme.whatsappTeal,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(15, (index) {
                      final heights = [6, 12, 18, 14, 8, 16, 22, 18, 12, 20, 14, 8, 12, 10, 6];
                      return Container(
                        width: 3,
                        height: heights[index % heights.length].toDouble(),
                        decoration: BoxDecoration(
                          color: isMe 
                              ? Colors.white.withValues(alpha: 0.8) 
                              : VybinTheme.secondaryText.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        durationText,
                        style: VybinTheme.caption.copyWith(
                          color: isMe ? Colors.white70 : VybinTheme.secondaryText,
                          fontSize: 10,
                        ),
                      ),
                      Icon(
                        Icons.mic,
                        size: 12,
                        color: isMe ? Colors.white70 : VybinTheme.secondaryText,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputZone() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: VybinTheme.darkCharcoal,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: VybinTheme.inputCharcoal,
                borderRadius: BorderRadius.circular(24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.emoji_emotions_outlined, color: VybinTheme.secondaryText),
                          onPressed: () {},
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: VybinTheme.body1,
                            decoration: const InputDecoration(
                              hintText: 'Message',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              filled: false,
                            ),
                            maxLines: 6,
                            minLines: 1,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.attach_file, color: VybinTheme.secondaryText),
                          onPressed: _showMediaBottomSheet,
                        ),
                        IconButton(
                          icon: const Icon(Icons.camera_alt_outlined, color: VybinTheme.secondaryText),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      left: _isRecording ? 0 : -MediaQuery.of(context).size.width,
                      right: _isRecording ? 0 : MediaQuery.of(context).size.width,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        color: VybinTheme.inputCharcoal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const GlowingCrimsonDot(),
                            const SizedBox(width: 12),
                            Text(
                              _formatDuration(_recordingDuration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Recording...',
                              style: VybinTheme.caption.copyWith(
                                color: VybinTheme.secondaryText,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              if (!_isTextEmpty) {
                _sendMessage();
              }
            },
            onLongPressStart: _isTextEmpty ? (_) => _startRecording() : null,
            onLongPressEnd: _isTextEmpty ? (_) => _stopRecording() : null,
            child: ScaleTransition(
              scale: _micAnimationScale,
              child: CircleAvatar(
                radius: 24,
                backgroundColor: VybinTheme.whatsappGreen,
                child: Icon(
                  _isTextEmpty ? Icons.mic : Icons.send,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GlowingCrimsonDot extends StatefulWidget {
  const GlowingCrimsonDot({super.key});

  @override
  State<GlowingCrimsonDot> createState() => _GlowingCrimsonDotState();
}

class _GlowingCrimsonDotState extends State<GlowingCrimsonDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacityAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.red,
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
