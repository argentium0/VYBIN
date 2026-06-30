import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:just_audio/just_audio.dart';
import '../../../core/services/media_service.dart';
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
  final MediaService _mediaService = MediaService();

  // Temporary hardcoded sender UID for MVP
  final String _currentUserId = 'my_uid_123';

  // Audio recording local states
  bool _isRecording = false;
  bool _isRecordingLocked = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  bool _isTextEmpty = true;

  // Drag coordinates for cancel/lock
  double _dragDy = 0.0;
  double _dragDx = 0.0;

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
            const SnackBar(content: Text('Microphone permission is required to record voice notes.')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e')),
        );
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
      final file = File('${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await file.writeAsBytes(bytes);

      final finalDuration = _recordingDuration > 0 ? _recordingDuration : 1;
      final durationString = _formatDuration(finalDuration);

      _chatBloc.add(SendMessage(
        plaintext: 'Voice Message ($durationString)',
        type: 'voice',
        senderUid: _currentUserId,
        mediaUrl: file.path,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving recording: $e')),
        );
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
                },
              ),
              _buildMediaOption(
                icon: Icons.mic,
                color: VybinTheme.whatsappTeal,
                label: 'Audio',
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              _buildMediaOption(
                icon: Icons.insert_drive_file,
                color: Colors.deepPurpleAccent,
                label: 'Document',
                onTap: () {
                  Navigator.pop(context);
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
                  Text(widget.contactName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                      reverse: true,
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
      return VoiceMessageBubble(
        message: message,
        isMe: isMe,
        mediaService: _mediaService,
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? VybinTheme.getSentBubbleColor(context) : VybinTheme.getReceivedBubbleColor(context),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.plaintext ?? '',
              style: VybinTheme.messageText.copyWith(
                color: isMe ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
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
                    color: isMe ? Colors.white.withOpacity(0.7) : VybinTheme.secondaryText,
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
      color = VybinTheme.neonBlue;
    } else if (status == 'delivered') {
      icon = Icons.done_all;
      color = Colors.white60;
    } else {
      icon = Icons.done;
      color = Colors.white60;
    }
    return Icon(icon, size: 14, color: color);
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
                              icon: const Icon(Icons.emoji_emotions_outlined, color: VybinTheme.secondaryText),
                              onPressed: () {},
                            ),
                            Expanded(
                              child: TextField(
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
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          left: _isRecording ? 0 : -MediaQuery.of(context).size.width,
                          right: _isRecording ? 0 : MediaQuery.of(context).size.width,
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
                                      const Icon(Icons.chevron_left, size: 16, color: VybinTheme.secondaryText),
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
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
                onLongPressStart: _isTextEmpty ? (_) => _startRecording() : null,
                onLongPressMoveUpdate: _isTextEmpty ? (details) => _onRecordingMoveUpdate(details) : null,
                onLongPressEnd: _isTextEmpty ? (details) => _onRecordingMoveEnd(details) : null,
                child: ScaleTransition(
                  scale: _micAnimationScale,
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: VybinTheme.whatsappGreen,
                    child: Icon(
                      (_isTextEmpty && !_isRecordingLocked) ? Icons.mic : Icons.send,
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
                    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, color: VybinTheme.secondaryText, size: 18),
                    SizedBox(height: 4),
                    Icon(Icons.keyboard_arrow_up, color: VybinTheme.secondaryText, size: 14),
                  ],
                ),
              ),
            ),
          ),
      ],
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
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  
  Timer? _simulationTimer;
  int _simulatedElapsedSeconds = 0;
  int _totalDurationSeconds = 0;

  @override
  void initState() {
    super.initState();
    _parseTotalDuration();
    _initAudioListeners();
  }

  void _parseTotalDuration() {
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
    
    _positionSub = player.positionStream.listen((pos) {
      if (widget.message.mediaUrl != null &&
          widget.mediaService.currentPlayingUrl == widget.message.mediaUrl) {
        if (mounted) {
          setState(() {
            _position = pos;
          });
        }
      }
    });

    _stateSub = player.playerStateStream.listen((state) {
      if (widget.message.mediaUrl != null &&
          widget.mediaService.currentPlayingUrl == widget.message.mediaUrl) {
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
    _simulationTimer?.cancel();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final mediaUrl = widget.message.mediaUrl;
    
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      final isCurrent = widget.mediaService.currentPlayingUrl == mediaUrl;
      if (isCurrent && _isPlaying) {
        await widget.mediaService.stopAudio();
      } else {
        if (widget.mediaService.currentPlayingUrl != null) {
          await widget.mediaService.stopAudio();
        }
        try {
          await widget.mediaService.playAudio(mediaUrl);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Playback failed: $e')),
            );
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
          color: isMe ? VybinTheme.getSentBubbleColor(context) : VybinTheme.getReceivedBubbleColor(context),
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
            GestureDetector(
              onTap: _togglePlayback,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: isMe ? Colors.white.withOpacity(0.2) : VybinTheme.whatsappTeal.withOpacity(0.2),
                child: Icon(
                  isPlayingThis ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: isMe ? Colors.white : VybinTheme.whatsappTeal,
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
                      final heights = [6, 12, 18, 14, 8, 16, 22, 18, 12, 20, 14, 8, 12, 10, 6];
                      final barHeight = heights[index % heights.length].toDouble();
                      
                      final barProgress = index / 15;
                      final isActive = isPlayingThis && barProgress <= progress;

                      return Container(
                        width: 3,
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: isActive
                              ? (isMe ? Colors.greenAccent : VybinTheme.whatsappGreen)
                              : (isMe 
                                  ? Colors.white.withOpacity(0.4) 
                                  : VybinTheme.secondaryText.withOpacity(0.4)),
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
                        isPlayingThis ? _formatDuration(currentPos) : _formatDuration(totalDur),
                        style: VybinTheme.caption.copyWith(
                          color: isMe 
                              ? (theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87) 
                              : VybinTheme.secondaryText,
                        ),
                      ),
                      if (isMe)
                        Icon(
                          Icons.done_all,
                          color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                          size: 16,
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
}
