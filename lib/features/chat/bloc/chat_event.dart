import 'package:equatable/equatable.dart';

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

class DeleteMessage extends ChatEvent {
  final String messageId;

  const DeleteMessage(this.messageId);

  @override
  List<Object?> get props => [messageId];
}
