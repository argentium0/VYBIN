import 'package:equatable/equatable.dart';
import 'package:vybin/shared/models/conversation_model.dart';

abstract class ChatListState extends Equatable {
  const ChatListState();

  @override
  List<Object?> get props => [];
}

class ChatListInitial extends ChatListState {}

class ChatListLoading extends ChatListState {}

class ChatListLoaded extends ChatListState {
  final List<ConversationModel> conversations;

  const ChatListLoaded(this.conversations);

  @override
  List<Object?> get props => [conversations];
}

class ChatListError extends ChatListState {
  final String errorMessage;

  const ChatListError(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
