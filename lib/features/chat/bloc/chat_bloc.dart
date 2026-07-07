import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vybin/features/chat/data/chat_repository.dart';
import 'package:vybin/shared/models/user_model.dart';
import 'package:vybin/shared/models/message_model.dart';
import '../models/message.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _chatRepository;
  final String _currentUid;
  
  StreamSubscription<List<MessageModel>>? _messagesSubscription;
  UserModel? _senderUser;
  UserModel? _recipientUser;

  ChatBloc({
    required ChatRepository chatRepository,
    required String currentUid,
  })  : _chatRepository = chatRepository,
        _currentUid = currentUid,
        super(ChatInitial()) {
    on<LoadMessages>(_onLoadMessages);
    on<SendMessage>(_onSendMessage);
    on<DeleteMessageForMeEvent>(_onDeleteMessageForMe);
    on<DeleteMessageForEveryoneEvent>(_onDeleteMessageForEveryone);
    on<UpdateMessagesReceived>(_onUpdateMessagesReceived);
  }

  Future<void> _onLoadMessages(LoadMessages event, Emitter<ChatState> emit) async {
    emit(ChatLoading());

    final uids = event.conversationId.split('_');
    final otherUid = uids.firstWhere((uid) => uid != _currentUid, orElse: () => '');

    try {
      _senderUser = await _chatRepository.getUserById(_currentUid);
      _recipientUser = await _chatRepository.getUserById(otherUid);

      await _messagesSubscription?.cancel();
      _messagesSubscription = _chatRepository
          .getMessagesStream(event.conversationId, _currentUid)
          .listen((msgModels) {
        final messages = msgModels.map(_mapModelToMessage).toList();
        if (!isClosed) {
          add(UpdateMessagesReceived(messages, event.conversationId));
        }

        // Whenever messages update, if there are unread messages from other user, mark as read
        _chatRepository.markMessagesAsRead(
          conversationId: event.conversationId,
          myUid: _currentUid,
        );
      });

      // Mark initially loaded messages as read
      await _chatRepository.markMessagesAsRead(
        conversationId: event.conversationId,
        myUid: _currentUid,
      );
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  void _onUpdateMessagesReceived(UpdateMessagesReceived event, Emitter<ChatState> emit) {
    emit(ChatLoaded(event.messages, event.conversationId));
  }

  Future<void> _onSendMessage(SendMessage event, Emitter<ChatState> emit) async {
    final currentState = state;
    if (currentState is ChatLoaded) {
      if (_senderUser == null || _recipientUser == null) {
        emit(const ChatError('User profiles not fully loaded.'));
        // Restore loaded state if it was loaded
        emit(currentState);
        return;
      }

      try {
        if (event.type == 'text') {
          await _chatRepository.sendMessage(
            conversationId: currentState.conversationId,
            senderUid: _currentUid,
            recipientUid: _recipientUser!.uid,
            plaintext: event.plaintext,
            senderPubKeyPEM: _senderUser!.publicKey,
            recipientPubKeyPEM: _recipientUser!.publicKey,
          );
        } else if (event.type == 'voice' || event.type == 'image' || event.type == 'video' || event.type == 'document') {
          await _chatRepository.sendMediaMessage(
            conversationId: currentState.conversationId,
            senderUid: _currentUid,
            recipientUid: _recipientUser!.uid,
            type: event.type,
            localFilePath: event.mediaUrl!,
            senderPubKeyPEM: _senderUser!.publicKey,
            recipientPubKeyPEM: _recipientUser!.publicKey,
            durationMs: event.durationMs,
          );
        }
      } catch (e) {
        emit(ChatError('Failed to send message: $e'));
        emit(currentState);
      }
    }
  }

  Future<void> _onDeleteMessageForMe(DeleteMessageForMeEvent event, Emitter<ChatState> emit) async {
    final currentState = state;
    if (currentState is ChatLoaded) {
      try {
        await _chatRepository.deleteMessageForMe(
          conversationId: currentState.conversationId,
          messageId: event.messageId,
          myUid: event.myUid,
        );
      } catch (_) {}
    }
  }

  Future<void> _onDeleteMessageForEveryone(DeleteMessageForEveryoneEvent event, Emitter<ChatState> emit) async {
    final currentState = state;
    if (currentState is ChatLoaded) {
      try {
        await _chatRepository.deleteMessageForEveryone(
          conversationId: currentState.conversationId,
          messageId: event.messageId,
        );
      } catch (_) {}
    }
  }

  Message _mapModelToMessage(MessageModel model) {
    return Message(
      messageId: model.messageId,
      senderUid: model.senderUid,
      timestamp: model.timestamp,
      type: model.type,
      iv: model.iv,
      ciphertext: model.ciphertext,
      encryptedKeys: model.encryptedKeys,
      plaintext: model.plaintext,
      status: model.status,
      deliveredAt: model.deliveredAt,
      readAt: model.readAt,
      mediaUrl: model.mediaUrl,
      mediaIv: model.mediaIv,
      mediaEncryptedKeys: model.mediaEncryptedKeys,
      mediaSize: model.mediaSize,
      mediaMimeType: model.mediaMimeType,
      mediaOriginalFilename: model.mediaOriginalFilename,
      durationMs: model.durationMs,
      deletedFor: model.deletedFor,
      deletedForEveryone: model.deletedForEveryone,
      deletedForEveryoneAt: model.deletedForEveryoneAt,
      isDeleted: model.isDeleted,
      hasDecryptionError: model.hasDecryptionError,
    );
  }

  @override
  Future<void> close() {
    _messagesSubscription?.cancel();
    return super.close();
  }
}
