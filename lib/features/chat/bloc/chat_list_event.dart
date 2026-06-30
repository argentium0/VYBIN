import 'package:equatable/equatable.dart';
import 'package:vybin/shared/models/conversation_model.dart';

abstract class ChatListEvent extends Equatable {
  const ChatListEvent();

  @override
  List<Object?> get props => [];
}

class LoadConversations extends ChatListEvent {}

class UpdateConversations extends ChatListEvent {
  final List<ConversationModel> conversations;

  const UpdateConversations(this.conversations);

  @override
  List<Object?> get props => [conversations];
}
