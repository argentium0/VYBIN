import 'package:equatable/equatable.dart';
import '../models/message.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<Message> messages;
  final String conversationId;

  const ChatLoaded(this.messages, this.conversationId);

  @override
  List<Object?> get props => [messages, conversationId];
}

class ChatError extends ChatState {
  final String message;

  const ChatError(this.message);

  @override
  List<Object?> get props => [message];
}
