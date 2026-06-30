import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../models/message.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final Uuid _uuid = const Uuid();

  ChatBloc() : super(ChatInitial()) {
    on<LoadMessages>(_onLoadMessages);
    on<SendMessage>(_onSendMessage);
    on<DeleteMessage>(_onDeleteMessage);
  }

  void _onLoadMessages(LoadMessages event, Emitter<ChatState> emit) {
    emit(ChatLoading());
    // Simulate loading messages from local storage or Firestore
    // For MVP phase 1, we start with an empty list
    emit(ChatLoaded(const [], event.conversationId));
  }

  void _onSendMessage(SendMessage event, Emitter<ChatState> emit) {
    if (state is ChatLoaded) {
      final currentState = state as ChatLoaded;
      
      final newMessage = Message(
        messageId: _uuid.v4(),
        senderUid: event.senderUid,
        timestamp: DateTime.now(),
        type: event.type,
        plaintext: event.plaintext, // For UI rendering before encryption
        status: 'sent',
        mediaUrl: event.mediaUrl,
      );

      final updatedMessages = List<Message>.from(currentState.messages)..insert(0, newMessage);

      emit(ChatLoaded(updatedMessages, currentState.conversationId));
    }
  }

  void _onDeleteMessage(DeleteMessage event, Emitter<ChatState> emit) {
    if (state is ChatLoaded) {
      final currentState = state as ChatLoaded;
      final updatedMessages = currentState.messages.where((m) => m.messageId != event.messageId).toList();
      emit(ChatLoaded(updatedMessages, currentState.conversationId));
    }
  }
}
