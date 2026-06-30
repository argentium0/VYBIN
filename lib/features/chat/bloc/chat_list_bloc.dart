import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vybin/shared/models/conversation_model.dart';
import 'chat_list_event.dart';
import 'chat_list_state.dart';

class ChatListBloc extends Bloc<ChatListEvent, ChatListState> {
  ChatListBloc() : super(ChatListInitial()) {
    on<LoadConversations>(_onLoadConversations);
    on<UpdateConversations>(_onUpdateConversations);
  }

  Future<void> _onLoadConversations(
    LoadConversations event,
    Emitter<ChatListState> emit,
  ) async {
    emit(ChatListLoading());

    // Simulate database/Firestore loading delay
    await Future.delayed(const Duration(milliseconds: 600));

    final mockConversations = [
      ConversationModel(
        conversationId: 'alice_vybin',
        participantUids: const ['my_uid_123', 'alice_uid'],
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        lastMessageAt: DateTime.now().subtract(const Duration(minutes: 25)),
        unreadCount: const {'my_uid_123': 2, 'alice_uid': 0},
        mutedBy: const [],
        deletedBy: const [],
        lastMessagePreview: const LastMessagePreview(
          senderUid: 'alice_uid',
          type: 'text',
          iv: 'mock_iv_base64',
          ciphertext: '🔒 Hey there! Did you get the key?',
          encryptedKeys: {},
        ),
      ),
      ConversationModel(
        conversationId: 'bob_d',
        participantUids: const ['my_uid_123', 'bob_uid'],
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        lastMessageAt: DateTime.now().subtract(const Duration(days: 1)),
        unreadCount: const {'my_uid_123': 0, 'bob_uid': 0},
        mutedBy: const [],
        deletedBy: const [],
        lastMessagePreview: const LastMessagePreview(
          senderUid: 'bob_uid',
          type: 'text',
          iv: 'mock_iv_base64',
          ciphertext: '🔒 AES-GCM session key generated successfully.',
          encryptedKeys: {},
        ),
      ),
      ConversationModel(
        conversationId: 'charlie_b',
        participantUids: const ['my_uid_123', 'charlie_uid'],
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        lastMessageAt: DateTime.now().subtract(const Duration(days: 2)),
        unreadCount: const {'my_uid_123': 0, 'charlie_uid': 0},
        mutedBy: const [],
        deletedBy: const [],
        lastMessagePreview: const LastMessagePreview(
          senderUid: 'charlie_uid',
          type: 'text',
          iv: 'mock_iv_base64',
          ciphertext: '🔒 Let\'s verify our RSA public keys.',
          encryptedKeys: {},
        ),
      ),
    ];

    emit(ChatListLoaded(mockConversations));
  }

  void _onUpdateConversations(
    UpdateConversations event,
    Emitter<ChatListState> emit,
  ) {
    emit(ChatListLoaded(event.conversations));
  }
}
