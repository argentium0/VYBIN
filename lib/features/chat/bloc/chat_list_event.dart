import 'package:equatable/equatable.dart';
import 'package:vybin/shared/models/conversation_model.dart';
import 'package:vybin/shared/models/user_model.dart';

abstract class ChatListEvent extends Equatable {
  const ChatListEvent();

  @override
  List<Object?> get props => [];
}

class LoadConversations extends ChatListEvent {}

class UpdateConversations extends ChatListEvent {
  final List<ConversationModel> conversations;
  final Map<String, UserModel> participants;

  const UpdateConversations(this.conversations, this.participants);

  @override
  List<Object?> get props => [conversations, participants];
}
