import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vybin/features/chat/data/chat_repository.dart';
import 'package:vybin/shared/models/conversation_model.dart';
import 'package:vybin/shared/models/user_model.dart';
import 'chat_list_event.dart';
import 'chat_list_state.dart';

class ChatListBloc extends Bloc<ChatListEvent, ChatListState> {
  final ChatRepository _chatRepository;
  final String _currentUid;
  StreamSubscription<List<ConversationModel>>? _conversationsSubscription;

  ChatListBloc({
    required ChatRepository chatRepository,
    required String currentUid,
  })  : _chatRepository = chatRepository,
        _currentUid = currentUid,
        super(ChatListInitial()) {
    on<LoadConversations>(_onLoadConversations);
    on<UpdateConversations>(_onUpdateConversations);
  }

  Future<void> _onLoadConversations(
    LoadConversations event,
    Emitter<ChatListState> emit,
  ) async {
    emit(ChatListLoading());

    await _conversationsSubscription?.cancel();
    _conversationsSubscription = _chatRepository
        .getConversationsStream(_currentUid)
        .listen((conversations) async {
      final participants = <String, UserModel>{};
      for (final conv in conversations) {
        final otherUid = conv.participantUids.firstWhere(
          (uid) => uid != _currentUid,
          orElse: () => '',
        );
        if (otherUid.isNotEmpty && !participants.containsKey(otherUid)) {
          final user = await _chatRepository.getUserById(otherUid);
          if (user != null) {
            participants[otherUid] = user;
          }
        }
      }

      if (!isClosed) {
        add(UpdateConversations(conversations, participants));
      }
    }, onError: (Object error) {
      if (!isClosed) {
        emit(ChatListError(error.toString()));
      }
    });
  }

  void _onUpdateConversations(
    UpdateConversations event,
    Emitter<ChatListState> emit,
  ) {
    emit(ChatListLoaded(event.conversations, event.participants));
  }

  @override
  Future<void> close() {
    _conversationsSubscription?.cancel();
    return super.close();
  }
}
