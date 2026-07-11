import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vybin/shared/models/user_model.dart';
import 'package:vybin/features/chat/data/chat_repository.dart';
import 'package:vybin/app.dart';
import '../../../core/services/media_service.dart';
import '../../../core/services/active_chat_tracker.dart';
import '../../../shared/theme/vybin_theme.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../models/message.dart';
import 'package:vybin/shared/utils/contact_display_helper.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

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

class _IndividualChatScreenState extends State<IndividualChatScreen>
    with SingleTickerProviderStateMixin {
  late ChatBloc _chatBloc;
  final TextEditingController _messageController = TextEditingController();
  final MediaService _mediaService = MediaService();

  late final String _currentUserId;
  late final String otherUid;

  // Audio recording local states
  bool _isRecording = false;
  bool _isRecordingLocked = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  bool _isTextEmpty = true;
  bool showEmojiPicker = false;
  final FocusNode textFocusNode = FocusNode();

  // Drag coordinates for cancel/lock
  double _dragDy = 0.0;
  double _dragDx = 0.0;

  late AnimationController _micAnimationController;
  late Animation<double> _micAnimationScale;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'my_uid_123';
    final uids = widget.conversationId.split('_');
    otherUid = uids.firstWhere(
      (uid) => uid != _currentUserId,
      orElse: () => '',
    );

    ActiveChatTracker.activeConversationId = widget.conversationId;
    _chatBloc = ChatBloc(
      chatRepository: context.read<ChatRepository>(),
      currentUid: _currentUserId,
    )..add(LoadMessages(widget.conversationId));
    _messageController.addListener(_onTextChanged);
    textFocusNode.addListener(() {
      if (textFocusNode.hasFocus) {
        setState(() {
          showEmojiPicker = false;
        });
      }
    });

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
    ActiveChatTracker.activeConversationId = null;
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    textFocusNode.dispose();
    _micAnimationController.dispose();
    _recordingTimer?.cancel();
    _mediaService.dispose();
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

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _mediaService.requestMicrophonePermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Microphone permission is required to record voice notes.',
              ),
            ),
          );
        }
        return;
      }

      setState(() {
        _isRecording = true;
        _isRecordingLocked = false;
        _recordingDuration = 0;
        _dragDx = 0.0;
        _dragDy = 0.0;
      });

      await _mediaService.startRecording();

      _micAnimationController.repeat(reverse: true);
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration++;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting recording: $e')));
      }
    }
  }

  Future<void> _stopRecording({bool shouldSend = true}) async {
    if (!_isRecording) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;
    _micAnimationController.stop();
    _micAnimationController.reset();

    setState(() {
      _isRecording = false;
      _isRecordingLocked = false;
    });

    try {
      final bytes = await _mediaService.stopRecording();
      if (!shouldSend || bytes == null) {
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      await file.writeAsBytes(bytes);

      final finalDuration = _recordingDuration > 0 ? _recordingDuration : 1;
      final durationString = _formatDuration(finalDuration);

      _chatBloc.add(
        SendMessage(
          plaintext: 'Voice Message ($durationString)',
          type: 'voice',
          senderUid: _currentUserId,
          mediaUrl: file.path,
          durationMs: finalDuration * 1000,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving recording: $e')));
      }
    }
  }

  void _onRecordingMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_isRecording || _isRecordingLocked) return;
    setState(() {
      _dragDy = details.localOffsetFromOrigin.dy;
      _dragDx = details.localOffsetFromOrigin.dx;
    });

    if (_dragDy < -80) {
      setState(() {
        _isRecordingLocked = true;
        _dragDy = 0.0;
        _dragDx = 0.0;
      });
    }

    if (_dragDx < -120) {
      _cancelRecording();
    }
  }

  void _onRecordingMoveEnd(LongPressEndDetails details) {
    if (_isRecordingLocked) {
      return;
    }
    _stopRecording(shouldSend: true);
  }

  void _cancelRecording() {
    _stopRecording(shouldSend: false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recording cancelled'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      _chatBloc.add(
        SendMessage(plaintext: text, type: 'text', senderUid: _currentUserId),
      );
      _messageController.clear();
    }
  }

  Future<void> _sendImageAttachment(ImageSource source) async {
    try {
      final hasPermission = source == ImageSource.camera
          ? await _mediaService.requestCameraPermission()
          : await _mediaService.requestStoragePermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${source == ImageSource.camera ? "Camera" : "Gallery"} permission is required.',
              ),
            ),
          );
        }
        return;
      }

      final file = await _mediaService.pickImage(source);
      if (file == null) return;

      final compressed = await _mediaService.compressImage(file);
      final finalFile = compressed ?? file;

      _chatBloc.add(
        SendMessage(
          plaintext: 'Sent an image 📷',
          type: 'image',
          senderUid: _currentUserId,
          mediaUrl: finalFile.path,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _sendVideoAttachment(ImageSource source) async {
    try {
      final hasPermission = source == ImageSource.camera
          ? await _mediaService.requestCameraPermission()
          : await _mediaService.requestStoragePermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${source == ImageSource.camera ? "Camera" : "Gallery"} permission is required.',
              ),
            ),
          );
        }
        return;
      }

      final file = await _mediaService.pickVideo(source);
      if (file == null) return;

      _chatBloc.add(
        SendMessage(
          plaintext: 'Sent a video 🎥',
          type: 'video',
          senderUid: _currentUserId,
          mediaUrl: file.path,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking video: $e')));
      }
    }
  }

  Future<void> _sendDocumentAttachment() async {
    try {
      final hasPermission = await _mediaService.requestStoragePermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission is required.')),
          );
        }
        return;
      }

      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.single.path == null) return;
      final filePath = result.files.single.path!;

      _chatBloc.add(
        SendMessage(
          plaintext: 'Sent a document 📎',
          type: 'document',
          senderUid: _currentUserId,
          mediaUrl: filePath,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking document: $e')));
      }
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
            color: Theme.of(context).colorScheme.surface,
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
                  _sendImageAttachment(ImageSource.camera);
                },
              ),
              _buildMediaOption(
                icon: Icons.photo_library,
                color: VybinTheme.whatsappTeal,
                label: 'Gallery',
                onTap: () {
                  Navigator.pop(context);
                  _sendImageAttachment(ImageSource.gallery);
                },
              ),
              _buildMediaOption(
                icon: Icons.video_library,
                color: Colors.orange,
                label: 'Video',
                onTap: () {
                  Navigator.pop(context);
                  _sendVideoAttachment(ImageSource.gallery);
                },
              ),
              _buildMediaOption(
                icon: Icons.insert_drive_file,
                color: Colors.deepPurpleAccent,
                label: 'Document',
                onTap: () {
                  Navigator.pop(context);
                  _sendDocumentAttachment();
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
    final contactId = otherUid;
    // ignore: avoid_print
    print('Zego Button Built for: $contactId');
    return BlocProvider.value(
      value: _chatBloc,
      child: BlocListener<ChatBloc, ChatState>(
        listener: (context, state) {
          if (state is ChatError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: VybinTheme.errorColor,
              ),
            );
          }
        },
        child: PopScope(
          canPop: !showEmojiPicker,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (showEmojiPicker) {
              setState(() {
                showEmojiPicker = false;
              });
            }
          },
          child: Scaffold(
            appBar: AppBar(
              titleSpacing: 0,
              title: StreamBuilder<UserModel?>(
                stream: context.read<ChatRepository>().getUserStream(
                  otherUid,
                  _currentUserId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text(
                      'Unable to load contact',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    );
                  }
                  final user = snapshot.data;
                  final customName = localContactAliases[otherUid];
                  final username = user?.username ?? otherUid;
                  final displayName = getContactDisplayName(
                    customName: customName,
                    username: username,
                  );

                  final cleanName = displayName.startsWith('@')
                      ? displayName.substring(1)
                      : displayName;
                  final initials = cleanName.length >= 2
                      ? cleanName.substring(0, 2).toUpperCase()
                      : cleanName.toUpperCase();

                  final statusText = _formatPresence(user);
                  final isOnline = user?.onlineStatus == 'online';

                  return GestureDetector(
                    onTap: () {
                      if (user != null) {
                        context.push(
                          '/chat/contact-profile/${user.uid}?conversationId=${widget.conversationId}',
                        );
                      }
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: VybinTheme.whatsappTeal,
                          backgroundImage:
                              (user?.profilePhotoUrl != null &&
                                  user!.profilePhotoUrl!.isNotEmpty)
                              ? NetworkImage(user.profilePhotoUrl!)
                              : null,
                          child:
                              (user?.profilePhotoUrl == null ||
                                  user!.profilePhotoUrl!.isEmpty)
                              ? Text(
                                  initials,
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            ValueListenableBuilder<bool>(
                              valueListenable:
                                  VybinApp.showActivityStatusNotifier,
                              builder: (context, showStatus, _) {
                                if (!showStatus || statusText.isEmpty)
                                  return const SizedBox.shrink();

                                return Row(
                                  children: [
                                    if (isOnline) ...[
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: VybinTheme.neonHighlight,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      statusText,
                                      style: VybinTheme.caption.copyWith(
                                        color: isOnline
                                            ? VybinTheme.neonHighlight
                                            : VybinTheme.secondaryText,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              actions: [
                StreamBuilder<UserModel?>(
                  stream: context.read<ChatRepository>().getUserStream(
                    otherUid,
                    _currentUserId,
                  ),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    final String contactId = otherUid;
                    final String contactName =
                        user?.username ?? widget.contactName;
                    return Center(
                      child: ZegoSendCallInvitationButton(
                        isVideoCall: false,
                        resourceID: 'vybin_call_resource',
                        invitees: [
                          ZegoUIKitUser(
                            id: contactId,
                            name: contactName,
                          ),
                        ],
                        icon: ButtonIcon(
                          icon: const Icon(
                            Icons.phone,
                            color: Colors.white,
                          ),
                        ),
                        iconSize: const Size(24, 24),
                        buttonSize: const Size(40, 40),
                        onWillPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Attempting to call ID: $contactId",
                              ),
                            ),
                          );
                          // Return true to tell Zego to continue with the call
                          return true;
                        },
                      ),
                    );
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'verify') {
                      context.push(
                        '/chat/${widget.conversationId}/verify',
                        extra: {'contactName': widget.contactName},
                      );
                    } else if (value == 'block') {
                      _showBlockUserBottomSheet(context);
                    } else if (value == 'report') {
                      _showReportChatBottomSheet(context);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'verify',
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: VybinTheme.neonHighlight,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Verify Keys',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(Icons.block, color: VybinTheme.errorColor),
                          SizedBox(width: 8),
                          Text(
                            'Block User',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(
                            Icons.report_problem_outlined,
                            color: Colors.orangeAccent,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Report Chat',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: BlocBuilder<ChatBloc, ChatState>(
                          builder: (context, state) {
                            if (state is ChatLoading) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: VybinTheme.neonHighlight,
                                ),
                              );
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
                                reverse: true,
                                padding: const EdgeInsets.all(16),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final message = messages[index];
                                  final isMe =
                                      message.senderUid == _currentUserId;
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
                if (showEmojiPicker)
                  SizedBox(
                    height: 250,
                    child: EmojiPicker(
                      textEditingController: _messageController,
                      config: Config(
                        height: 250,
                        checkPlatformCompatibility: true,
                        emojiViewConfig: EmojiViewConfig(
                          backgroundColor: Theme.of(
                            context,
                          ).scaffoldBackgroundColor,
                        ),
                        categoryViewConfig: CategoryViewConfig(
                          backgroundColor: Theme.of(
                            context,
                          ).scaffoldBackgroundColor,
                          indicatorColor: Theme.of(context).colorScheme.primary,
                          iconColor: Colors.grey,
                          iconColorSelected: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // floatingActionButton: FloatingActionButton(
            //   backgroundColor: Colors.red,
            //   onPressed: () {
            //     print("🚨 EMERGENCY BUTTON TAPPED!");
            //     ScaffoldMessenger.of(context).showSnackBar(
            //       SnackBar(content: Text("BUTTON IS ALIVE!"))
            //     );
            //   },
            //   child: Icon(Icons.touch_app),
            // ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(Message message, bool isMe) {
    if (message.hasDecryptionError) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMe
                ? VybinTheme.getSentBubbleColor(context).withValues(alpha: 0.5)
                : VybinTheme.getReceivedBubbleColor(
                    context,
                  ).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '🔒 Waiting for key migration...',
            style: TextStyle(
              color: Colors.white60,
              fontStyle: FontStyle.italic,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    if (message.isDeleted) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMe
                ? VybinTheme.getSentBubbleColor(context).withValues(alpha: 0.5)
                : VybinTheme.getReceivedBubbleColor(
                    context,
                  ).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isMe
                ? '🚫 You deleted this message.'
                : '🚫 This message was deleted.',
            style: const TextStyle(
              color: Colors.white60,
              fontStyle: FontStyle.italic,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    Widget bubbleChild;
    if (message.type == 'voice') {
      bubbleChild = VoiceMessageBubble(
        message: message,
        isMe: isMe,
        mediaService: _mediaService,
      );
    } else if (message.type == 'image') {
      bubbleChild = ImageMessageBubble(
        message: message,
        isMe: isMe,
        currentUserId: _currentUserId,
      );
    } else if (message.type == 'video') {
      bubbleChild = VideoMessageBubble(
        message: message,
        isMe: isMe,
        currentUserId: _currentUserId,
      );
    } else if (message.type == 'document') {
      bubbleChild = DocumentMessageBubble(
        message: message,
        isMe: isMe,
        currentUserId: _currentUserId,
      );
    } else {
      bubbleChild = Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMe
                ? VybinTheme.getSentBubbleColor(context)
                : VybinTheme.getReceivedBubbleColor(context),
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
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.plaintext ?? '',
                style: VybinTheme.messageText.copyWith(
                  color: isMe
                      ? Colors.white
                      : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : VybinTheme.secondaryText,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildStatusTicks(message.status),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => _showDeleteMessageBottomSheet(message, isMe),
      child: bubbleChild,
    );
  }

  void _showDeleteMessageBottomSheet(Message message, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Delete Message?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: VybinTheme.errorColor,
                ),
                title: const Text(
                  'Delete for Me',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _chatBloc.add(
                    DeleteMessageForMeEvent(
                      messageId: message.messageId,
                      myUid: _currentUserId,
                    ),
                  );
                },
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever,
                    color: VybinTheme.errorColor,
                  ),
                  title: const Text(
                    'Delete for Everyone',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _chatBloc.add(
                      DeleteMessageForEveryoneEvent(
                        messageId: message.messageId,
                      ),
                    );
                  },
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: VybinTheme.secondaryText),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildStatusTicks(String status) {
    IconData icon;
    Color color;
    if (status == 'read') {
      icon = Icons.done_all;
      color = Colors.blue;
    } else if (status == 'delivered') {
      icon = Icons.done_all;
      color = Colors.grey;
    } else {
      icon = Icons.check;
      color = Colors.grey;
    }
    return Icon(icon, size: 14, color: color);
  }

  String _formatPresence(UserModel? user) {
    if (user == null) return '';
    if (user.onlineStatus == 'online') {
      return 'Online';
    }

    final difference = DateTime.now().difference(user.lastSeen);
    if (difference.inMinutes < 1) {
      return 'Active just now';
    } else if (difference.inMinutes < 60) {
      return 'Active ${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return 'Active ${difference.inHours}h ago';
    } else {
      return 'Active ${difference.inDays}d ago';
    }
  }

  Widget _buildInputZone() {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: theme.scaffoldBackgroundColor,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.inputDecorationTheme.fillColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                showEmojiPicker
                                    ? Icons.keyboard_outlined
                                    : Icons.emoji_emotions_outlined,
                                color: VybinTheme.secondaryText,
                              ),
                              onPressed: () {
                                setState(() {
                                  showEmojiPicker = !showEmojiPicker;
                                });
                                if (showEmojiPicker) {
                                  textFocusNode.unfocus();
                                }
                              },
                            ),
                            Expanded(
                              child: TextField(
                                focusNode: textFocusNode,
                                controller: _messageController,
                                style: VybinTheme.body1,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _sendMessage(),
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
                              icon: const Icon(
                                Icons.attach_file,
                                color: VybinTheme.secondaryText,
                              ),
                              onPressed: _showMediaBottomSheet,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.camera_alt_outlined,
                                color: VybinTheme.secondaryText,
                              ),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          left: _isRecording
                              ? 0
                              : -MediaQuery.of(context).size.width,
                          right: _isRecording
                              ? 0
                              : MediaQuery.of(context).size.width,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            color: theme.inputDecorationTheme.fillColor,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                const GlowingCrimsonDot(),
                                const SizedBox(width: 12),
                                Text(
                                  _formatDuration(_recordingDuration),
                                  style: TextStyle(
                                    color: onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Spacer(),
                                if (!_isRecordingLocked) ...[
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.chevron_left,
                                        size: 16,
                                        color: VybinTheme.secondaryText,
                                      ),
                                      Text(
                                        'Swipe to cancel',
                                        style: VybinTheme.caption.copyWith(
                                          color: VybinTheme.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: _cancelRecording,
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Locked recording...',
                                    style: VybinTheme.caption.copyWith(
                                      color: VybinTheme.whatsappGreen,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
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
                  } else if (_isRecordingLocked) {
                    _stopRecording(shouldSend: true);
                  }
                },
                onLongPressStart: _isTextEmpty
                    ? (_) => _startRecording()
                    : null,
                onLongPressMoveUpdate: _isTextEmpty
                    ? (details) => _onRecordingMoveUpdate(details)
                    : null,
                onLongPressEnd: _isTextEmpty
                    ? (details) => _onRecordingMoveEnd(details)
                    : null,
                child: ScaleTransition(
                  scale: _micAnimationScale,
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: VybinTheme.whatsappGreen,
                    child: Icon(
                      (_isTextEmpty && !_isRecordingLocked)
                          ? Icons.mic
                          : Icons.send,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isRecording && !_isRecordingLocked)
          Positioned(
            right: 16,
            bottom: 72 + (_dragDy < 0 ? _dragDy : 0),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isRecording ? 1.0 : 0.0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, color: VybinTheme.secondaryText, size: 18),
                    SizedBox(height: 4),
                    Icon(
                      Icons.keyboard_arrow_up,
                      color: VybinTheme.secondaryText,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showBlockUserBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VybinTheme.cardCharcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.block, color: VybinTheme.errorColor, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Block ${widget.contactName}?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Blocked users will not be able to send you messages, and their presence updates will be hidden from your feed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: VybinTheme.secondaryText,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VybinTheme.errorColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    try {
                      final chatRepo = context.read<ChatRepository>();
                      await chatRepo.blockUser(_currentUserId, otherUid);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${widget.contactName} blocked.'),
                          ),
                        );
                        context.pop(); // Go back to chat list
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to block user: $e')),
                        );
                      }
                    }
                  },
                  child: const Text(
                    'Block User',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: VybinTheme.secondaryText),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReportChatBottomSheet(BuildContext context) {
    final commentController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: VybinTheme.cardCharcoal,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.report_problem_outlined,
                color: Colors.orangeAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Report ${widget.contactName}?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Because VYBIN is strictly end-to-end encrypted, no message text will be sent to the server. Only infrastructural metadata (timestamps, handshakes) and your voluntary comment below will be forwarded.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: VybinTheme.secondaryText,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLength: 500,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Voluntary comments (e.g. description of abuse)',
                  labelStyle: TextStyle(color: VybinTheme.secondaryText),
                  counterStyle: TextStyle(color: VybinTheme.secondaryText),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  final reason = commentController.text.trim();
                  Navigator.of(sheetContext).pop();
                  try {
                    final chatRepo = context.read<ChatRepository>();
                    await chatRepo.reportConversation(
                      conversationId: widget.conversationId,
                      reporterUid: _currentUserId,
                      reportedUid: otherUid,
                      reason: reason,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Chat report submitted successfully.'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to submit report: $e')),
                      );
                    }
                  }
                },
                child: const Text(
                  'Submit Report',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: VybinTheme.secondaryText),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class GlowingCrimsonDot extends StatefulWidget {
  const GlowingCrimsonDot({super.key});

  @override
  State<GlowingCrimsonDot> createState() => _GlowingCrimsonDotState();
}

class _GlowingCrimsonDotState extends State<GlowingCrimsonDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacityAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(_controller);
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
            BoxShadow(color: Colors.red, blurRadius: 8, spreadRadius: 2),
          ],
        ),
      ),
    );
  }
}

class VoiceMessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final MediaService mediaService;

  const VoiceMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.mediaService,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _durationSub;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  Timer? _simulationTimer;
  int _simulatedElapsedSeconds = 0;
  int _totalDurationSeconds = 0;

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _parseTotalDuration();
    _initAudioListeners();
  }

  void _parseTotalDuration() {
    if (widget.message.durationMs != null && widget.message.durationMs! > 0) {
      _totalDurationSeconds = widget.message.durationMs! ~/ 1000;
      _duration = Duration(milliseconds: widget.message.durationMs!);
      return;
    }

    final plaintext = widget.message.plaintext ?? '';
    final start = plaintext.indexOf('(');
    final end = plaintext.indexOf(')');
    if (start != -1 && end != -1 && end > start) {
      final parts = plaintext.substring(start + 1, end).split(':');
      if (parts.length == 2) {
        final m = int.tryParse(parts[0]) ?? 0;
        final s = int.tryParse(parts[1]) ?? 0;
        _totalDurationSeconds = m * 60 + s;
        _duration = Duration(seconds: _totalDurationSeconds);
      }
    }
    if (_totalDurationSeconds == 0) {
      _totalDurationSeconds = 5;
      _duration = const Duration(seconds: 5);
    }
  }

  void _initAudioListeners() {
    final player = widget.mediaService.audioPlayer;
    final mediaId = widget.message.messageId;

    _positionSub = player.positionStream.listen((pos) {
      final currentUrl = widget.mediaService.currentPlayingUrl;
      final isCurrent =
          widget.message.mediaUrl != null &&
          (currentUrl == widget.message.mediaUrl ||
              (currentUrl != null && currentUrl.contains(mediaId)));
      if (isCurrent) {
        if (mounted) {
          setState(() {
            _position = pos;
          });
        }
      }
    });

    _durationSub = player.durationStream.listen((dur) {
      final currentUrl = widget.mediaService.currentPlayingUrl;
      final isCurrent =
          widget.message.mediaUrl != null &&
          (currentUrl == widget.message.mediaUrl ||
              (currentUrl != null && currentUrl.contains(mediaId)));
      if (isCurrent && dur != null) {
        if (mounted) {
          setState(() {
            _duration = dur;
            _totalDurationSeconds = dur.inSeconds;
          });
        }
      }
    });

    _stateSub = player.playerStateStream.listen((state) {
      final currentUrl = widget.mediaService.currentPlayingUrl;
      final isCurrent =
          widget.message.mediaUrl != null &&
          (currentUrl == widget.message.mediaUrl ||
              (currentUrl != null && currentUrl.contains(mediaId)));
      if (isCurrent) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            if (state.processingState == ProcessingState.completed) {
              _position = Duration.zero;
              _isPlaying = false;
            }
          });
        }
      } else {
        if (_isPlaying && widget.message.mediaUrl != null) {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _position = Duration.zero;
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    _durationSub?.cancel();
    _simulationTimer?.cancel();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final mediaUrl = widget.message.mediaUrl;

    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      String localPath = mediaUrl;
      if (mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://')) {
        try {
          if (mounted) {
            setState(() {
              _isLoading = true;
              _error = null;
            });
          }
          final tempDir = await getTemporaryDirectory();
          final decryptedFile = File(
            '${tempDir.path}/decrypted_${widget.message.messageId}.m4a',
          );

          if (!await decryptedFile.exists()) {
            final client = HttpClient();
            final request = await client.getUrl(Uri.parse(mediaUrl));
            final response = await request.close();
            if (response.statusCode != 200) {
              throw Exception('Failed downloading voice note');
            }
            final encryptedBytes = await response.fold<List<int>>(
              [],
              (a, b) => a..addAll(b),
            );

            final encryptedKeys = widget.message.mediaEncryptedKeys ?? {};
            final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
            final myKey = encryptedKeys[myUid];
            if (myKey == null) {
              throw Exception('No key for you');
            }

            final mediaIv = widget.message.mediaIv;
            if (mediaIv == null) {
              throw Exception('No IV');
            }

            if (!mounted) return;
            final chatRepo = context.read<ChatRepository>();
            final decryptedBytes = chatRepo.decryptMediaBytes(
              encryptedBytes: Uint8List.fromList(encryptedBytes),
              iv: mediaIv,
              encryptedKey: myKey,
            );

            await decryptedFile.writeAsBytes(decryptedBytes);
          }
          localPath = decryptedFile.path;
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _error = 'Failed to load audio';
            });
          }
          return;
        }
      }

      final isCurrent = widget.mediaService.currentPlayingUrl == localPath;
      if (isCurrent && _isPlaying) {
        await widget.mediaService.stopAudio();
      } else {
        if (widget.mediaService.currentPlayingUrl != null) {
          await widget.mediaService.stopAudio();
        }
        try {
          await widget.mediaService.playAudio(localPath);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Playback failed: $e')));
          }
        }
      }
    } else {
      if (_isPlaying) {
        _stopSimulation();
      } else {
        _startSimulation();
      }
    }
  }

  void _startSimulation() {
    widget.mediaService.stopAudio();

    setState(() {
      _isPlaying = true;
      _simulatedElapsedSeconds = 0;
      _position = Duration.zero;
    });

    _simulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _simulatedElapsedSeconds++;
          _position = Duration(seconds: _simulatedElapsedSeconds);
          if (_simulatedElapsedSeconds >= _totalDurationSeconds) {
            _stopSimulation();
          }
        });
      }
    });
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
        _simulatedElapsedSeconds = 0;
      });
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMe = widget.isMe;
    final isPlayingThis = _isPlaying;

    final currentPos = _position;
    final totalDur = _duration;

    double progress = 0.0;
    if (totalDur.inMilliseconds > 0) {
      progress = currentPos.inMilliseconds / totalDur.inMilliseconds;
      if (progress > 1.0) progress = 1.0;
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 290),
        decoration: BoxDecoration(
          color: isMe
              ? VybinTheme.getSentBubbleColor(context)
              : VybinTheme.getReceivedBubbleColor(context),
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
            ),
          ],
        ),
        child: _error != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: _togglePlayback,
                    icon: const Icon(
                      Icons.refresh,
                      size: 14,
                      color: VybinTheme.whatsappGreen,
                    ),
                    label: const Text(
                      'Tap to Retry',
                      style: TextStyle(
                        color: VybinTheme.whatsappGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _isLoading
                      ? const SizedBox(
                          width: 36,
                          height: 36,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: VybinTheme.whatsappGreen,
                            ),
                          ),
                        )
                      : GestureDetector(
                          onTap: _togglePlayback,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: isMe
                                ? Colors.white.withValues(alpha: 0.2)
                                : VybinTheme.whatsappTeal.withValues(
                                    alpha: 0.2,
                                  ),
                            child: Icon(
                              isPlayingThis
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: isMe
                                  ? Colors.white
                                  : VybinTheme.whatsappTeal,
                              size: 24,
                            ),
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
                            final heights = [
                              6,
                              12,
                              18,
                              14,
                              8,
                              16,
                              22,
                              18,
                              12,
                              20,
                              14,
                              8,
                              12,
                              10,
                              6,
                            ];
                            final barHeight = heights[index % heights.length]
                                .toDouble();

                            final barProgress = index / 15;
                            final isActive =
                                isPlayingThis && barProgress <= progress;

                            return Container(
                              width: 3,
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? (isMe
                                          ? Colors.greenAccent
                                          : VybinTheme.whatsappGreen)
                                    : (isMe
                                          ? Colors.white.withValues(alpha: 0.4)
                                          : VybinTheme.secondaryText.withValues(
                                              alpha: 0.4,
                                            )),
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
                              isPlayingThis
                                  ? _formatDuration(currentPos)
                                  : _formatDuration(totalDur),
                              style: VybinTheme.caption.copyWith(
                                color: isMe
                                    ? (theme.brightness == Brightness.dark
                                          ? Colors.white70
                                          : Colors.black87)
                                    : VybinTheme.secondaryText,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              _buildStatusTicks(widget.message.status),
                            ],
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

  Widget _buildStatusTicks(String status) {
    IconData icon;
    Color color;
    if (status == 'read') {
      icon = Icons.done_all;
      color = Colors.blue;
    } else if (status == 'delivered') {
      icon = Icons.done_all;
      color = Colors.grey;
    } else {
      icon = Icons.check;
      color = Colors.grey;
    }
    return Icon(icon, size: 14, color: color);
  }
}

class ImageMessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final String currentUserId;

  const ImageMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.currentUserId,
  });

  @override
  State<ImageMessageBubble> createState() => _ImageMessageBubbleState();
}

class _ImageMessageBubbleState extends State<ImageMessageBubble> {
  bool _isLoading = false;
  String? _error;
  Uint8List? _decryptedBytes;

  @override
  void initState() {
    super.initState();
    _loadAndDecryptImage();
  }

  Future<void> _loadAndDecryptImage() async {
    final mediaUrl = widget.message.mediaUrl;
    if (mediaUrl == null || mediaUrl.isEmpty) {
      setState(() {
        _error = 'No media URL';
      });
      return;
    }

    final filename = widget.message.mediaOriginalFilename ?? 'image.jpg';
    final messageId = widget.message.messageId;

    try {
      final tempDir = await getTemporaryDirectory();
      final cacheFile = File(
        '${tempDir.path}/decrypted_${messageId}_$filename',
      );

      // 1. Check if the file exists in the local cache
      if (await cacheFile.exists()) {
        final bytes = await cacheFile.readAsBytes();
        if (mounted) {
          setState(() {
            _decryptedBytes = bytes;
          });
        }
        return;
      }

      // 2. Download encrypted bytes
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(mediaUrl));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('Download failed: Status ${response.statusCode}');
      }
      final encryptedBytes = await response.fold<List<int>>(
        [],
        (a, b) => a..addAll(b),
      );

      // 3. Retrieve wrapped AES key
      final encryptedKeys = widget.message.mediaEncryptedKeys ?? {};
      final myKey = encryptedKeys[widget.currentUserId];
      if (myKey == null) {
        throw Exception('Access key not found for current user.');
      }

      final mediaIv = widget.message.mediaIv;
      if (mediaIv == null || mediaIv.isEmpty) {
        throw Exception('Missing IV');
      }

      // 4. Decrypt in memory
      if (!mounted) return;
      final chatRepo = context.read<ChatRepository>();
      final decrypted = chatRepo.decryptMediaBytes(
        encryptedBytes: Uint8List.fromList(encryptedBytes),
        iv: mediaIv,
        encryptedKey: myKey,
      );

      // Write to local cache
      await cacheFile.writeAsBytes(decrypted);

      if (mounted) {
        setState(() {
          _decryptedBytes = decrypted;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Decryption failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;

    Widget content;
    if (_decryptedBytes != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          _decryptedBytes!,
          fit: BoxFit.cover,
          height: 200,
          width: double.infinity,
        ),
      );
    } else if (_isLoading) {
      content = const SizedBox(
        height: 150,
        child: Center(
          child: CircularProgressIndicator(color: VybinTheme.whatsappGreen),
        ),
      );
    } else if (_error != null) {
      content = Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              onPressed: _loadAndDecryptImage,
              icon: const Icon(
                Icons.refresh,
                size: 14,
                color: VybinTheme.whatsappGreen,
              ),
              label: const Text(
                'Retry Download',
                style: TextStyle(
                  color: VybinTheme.whatsappGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      content = const SizedBox(height: 150);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(maxWidth: 250),
        decoration: BoxDecoration(
          color: isMe
              ? VybinTheme.getSentBubbleColor(context)
              : VybinTheme.getReceivedBubbleColor(context),
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
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            content,
            Padding(
              padding: const EdgeInsets.only(top: 4.0, right: 8.0, bottom: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(widget.message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : VybinTheme.secondaryText,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildStatusTicks(widget.message.status),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildStatusTicks(String status) {
    IconData icon;
    Color color;
    if (status == 'read') {
      icon = Icons.done_all;
      color = Colors.blue;
    } else if (status == 'delivered') {
      icon = Icons.done_all;
      color = Colors.grey;
    } else {
      icon = Icons.check;
      color = Colors.grey;
    }
    return Icon(icon, size: 14, color: color);
  }
}

class DocumentMessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final String currentUserId;

  const DocumentMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.currentUserId,
  });

  @override
  State<DocumentMessageBubble> createState() => _DocumentMessageBubbleState();
}

class _DocumentMessageBubbleState extends State<DocumentMessageBubble> {
  bool _isLoading = false;
  String? _error;
  File? _decryptedFile;

  @override
  void initState() {
    super.initState();
    _loadAndDecryptDocument();
  }

  Future<void> _loadAndDecryptDocument() async {
    final mediaUrl = widget.message.mediaUrl;
    if (mediaUrl == null || mediaUrl.isEmpty) {
      setState(() {
        _error = 'No media URL';
      });
      return;
    }

    final filename = widget.message.mediaOriginalFilename ?? 'document.pdf';
    final messageId = widget.message.messageId;

    try {
      final tempDir = await getTemporaryDirectory();
      final cacheFile = File(
        '${tempDir.path}/decrypted_${messageId}_$filename',
      );

      // 1. Check if the file exists in the local cache
      if (await cacheFile.exists()) {
        if (mounted) {
          setState(() {
            _decryptedFile = cacheFile;
          });
        }
        return;
      }

      // 2. Download encrypted bytes
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(mediaUrl));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('Download failed: Status ${response.statusCode}');
      }
      final encryptedBytes = await response.fold<List<int>>(
        [],
        (a, b) => a..addAll(b),
      );

      // 3. Retrieve wrapped AES key
      final encryptedKeys = widget.message.mediaEncryptedKeys ?? {};
      final myKey = encryptedKeys[widget.currentUserId];
      if (myKey == null) {
        throw Exception('Access key not found for current user.');
      }

      final mediaIv = widget.message.mediaIv;
      if (mediaIv == null || mediaIv.isEmpty) {
        throw Exception('Missing IV');
      }

      // 4. Decrypt in memory
      if (!mounted) return;
      final chatRepo = context.read<ChatRepository>();
      final decrypted = chatRepo.decryptMediaBytes(
        encryptedBytes: Uint8List.fromList(encryptedBytes),
        iv: mediaIv,
        encryptedKey: myKey,
      );

      // Write to local cache
      await cacheFile.writeAsBytes(decrypted);

      if (mounted) {
        setState(() {
          _decryptedFile = cacheFile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Decryption failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openDocument() async {
    if (_decryptedFile != null) {
      try {
        await OpenFile.open(_decryptedFile!.path);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Could not open file: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final filename = widget.message.mediaOriginalFilename ?? 'document';
    final size = widget.message.mediaSize != null
        ? '${(widget.message.mediaSize! / 1024).toStringAsFixed(1)} KB'
        : '';

    Widget content;
    if (_isLoading) {
      content = const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: VybinTheme.whatsappGreen,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Downloading document...',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    } else if (_error != null) {
      content = Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              onPressed: _loadAndDecryptDocument,
              icon: const Icon(
                Icons.refresh,
                size: 14,
                color: VybinTheme.whatsappGreen,
              ),
              label: const Text(
                'Retry Download',
                style: TextStyle(
                  color: VybinTheme.whatsappGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      content = ListTile(
        onTap: _openDocument,
        dense: true,
        leading: const Icon(
          Icons.insert_drive_file,
          color: VybinTheme.whatsappGreen,
          size: 36,
        ),
        title: Text(
          filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: size.isNotEmpty
            ? Text(size, style: const TextStyle(color: Colors.white70))
            : null,
        trailing: const Icon(
          Icons.open_in_new,
          color: Colors.white54,
          size: 20,
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
        constraints: const BoxConstraints(maxWidth: 290),
        decoration: BoxDecoration(
          color: isMe
              ? VybinTheme.getSentBubbleColor(context)
              : VybinTheme.getReceivedBubbleColor(context),
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
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            content,
            Padding(
              padding: const EdgeInsets.only(
                top: 2.0,
                right: 12.0,
                bottom: 6.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(widget.message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : VybinTheme.secondaryText,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildStatusTicks(widget.message.status),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildStatusTicks(String status) {
    IconData icon;
    Color color;
    if (status == 'read') {
      icon = Icons.done_all;
      color = Colors.blue;
    } else if (status == 'delivered') {
      icon = Icons.done_all;
      color = Colors.grey;
    } else {
      icon = Icons.check;
      color = Colors.grey;
    }
    return Icon(icon, size: 14, color: color);
  }
}

class VideoMessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final String currentUserId;

  const VideoMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.currentUserId,
  });

  @override
  State<VideoMessageBubble> createState() => _VideoMessageBubbleState();
}

class _VideoMessageBubbleState extends State<VideoMessageBubble> {
  bool _isLoading = false;
  String? _error;
  File? _decryptedFile;

  @override
  void initState() {
    super.initState();
    _loadAndDecryptVideo();
  }

  Future<void> _loadAndDecryptVideo() async {
    final mediaUrl = widget.message.mediaUrl;
    if (mediaUrl == null || mediaUrl.isEmpty) {
      setState(() {
        _error = 'No media URL';
      });
      return;
    }

    final filename = widget.message.mediaOriginalFilename ?? 'video.mp4';
    final messageId = widget.message.messageId;

    try {
      final tempDir = await getTemporaryDirectory();
      final cacheFile = File(
        '${tempDir.path}/decrypted_${messageId}_$filename',
      );

      // 1. Check if the file exists in the local cache
      if (await cacheFile.exists()) {
        if (mounted) {
          setState(() {
            _decryptedFile = cacheFile;
          });
        }
        return;
      }

      // 2. Download encrypted bytes
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(mediaUrl));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('Download failed: Status ${response.statusCode}');
      }
      final encryptedBytes = await response.fold<List<int>>(
        [],
        (a, b) => a..addAll(b),
      );

      // 3. Retrieve wrapped AES key
      final encryptedKeys = widget.message.mediaEncryptedKeys ?? {};
      final myKey = encryptedKeys[widget.currentUserId];
      if (myKey == null) {
        throw Exception('Access key not found for current user.');
      }

      final mediaIv = widget.message.mediaIv;
      if (mediaIv == null || mediaIv.isEmpty) {
        throw Exception('Missing IV');
      }

      // 4. Decrypt in memory
      if (!mounted) return;
      final chatRepo = context.read<ChatRepository>();
      final decrypted = chatRepo.decryptMediaBytes(
        encryptedBytes: Uint8List.fromList(encryptedBytes),
        iv: mediaIv,
        encryptedKey: myKey,
      );

      // Write to local cache
      await cacheFile.writeAsBytes(decrypted);

      if (mounted) {
        setState(() {
          _decryptedFile = cacheFile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Decryption failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openVideo() async {
    if (_decryptedFile != null) {
      try {
        await OpenFile.open(_decryptedFile!.path);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Could not open video: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final filename = widget.message.mediaOriginalFilename ?? 'video.mp4';
    final size = widget.message.mediaSize != null
        ? '${(widget.message.mediaSize! / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '';

    Widget content;
    if (_isLoading) {
      content = const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: VybinTheme.whatsappGreen,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Downloading video...',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    } else if (_error != null) {
      content = Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              onPressed: _loadAndDecryptVideo,
              icon: const Icon(
                Icons.refresh,
                size: 14,
                color: VybinTheme.whatsappGreen,
              ),
              label: const Text(
                'Retry Download',
                style: TextStyle(
                  color: VybinTheme.whatsappGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      content = ListTile(
        onTap: _openVideo,
        dense: true,
        leading: const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.play_arrow, color: Colors.white),
        ),
        title: Text(
          filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: size.isNotEmpty
            ? Text(size, style: const TextStyle(color: Colors.white70))
            : null,
        trailing: const Icon(
          Icons.open_in_new,
          color: Colors.white54,
          size: 20,
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
        constraints: const BoxConstraints(maxWidth: 290),
        decoration: BoxDecoration(
          color: isMe
              ? VybinTheme.getSentBubbleColor(context)
              : VybinTheme.getReceivedBubbleColor(context),
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
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            content,
            Padding(
              padding: const EdgeInsets.only(
                top: 2.0,
                right: 12.0,
                bottom: 6.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(widget.message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : VybinTheme.secondaryText,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildStatusTicks(widget.message.status),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildStatusTicks(String status) {
    IconData icon;
    Color color;
    if (status == 'read') {
      icon = Icons.done_all;
      color = Colors.blue;
    } else if (status == 'delivered') {
      icon = Icons.done_all;
      color = Colors.grey;
    } else {
      icon = Icons.check;
      color = Colors.grey;
    }
    return Icon(icon, size: 14, color: color);
  }
}
