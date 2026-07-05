import 'package:equatable/equatable.dart';
import '../models/message.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class LoadMessages extends ChatEvent {
  final String conversationId;

  const LoadMessages(this.conversationId);

  @override
  List<Object?> get props => [conversationId];
}

class SendMessage extends ChatEvent {
  final String plaintext;
  final String type; // 'text', 'image', 'voice', 'document'
  final String senderUid;
  final String? mediaUrl;

  const SendMessage({
    required this.plaintext,
    required this.type,
    required this.senderUid,
    this.mediaUrl,
  });

  @override
  List<Object?> get props => [plaintext, type, senderUid, mediaUrl];
}

class DeleteMessageForMeEvent extends ChatEvent {
  final String messageId;
  final String myUid;

  const DeleteMessageForMeEvent({required this.messageId, required this.myUid});

  @override
  List<Object?> get props => [messageId, myUid];
}

class DeleteMessageForEveryoneEvent extends ChatEvent {
  final String messageId;

  const DeleteMessageForEveryoneEvent({required this.messageId});

  @override
  List<Object?> get props => [messageId];
}

class UpdateMessagesReceived extends ChatEvent {
  final List<Message> messages;
  final String conversationId;
  const UpdateMessagesReceived(this.messages, this.conversationId);

  @override
  List<Object?> get props => [messages, conversationId];
}
