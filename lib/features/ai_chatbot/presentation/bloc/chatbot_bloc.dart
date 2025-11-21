import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecases/usecase.dart';
import '../../data/models/chat_message.dart';
import '../../domain/repositories/chatbot_repository.dart';
import '../../domain/usecases/clear_chat_history_usecase.dart';
import '../../domain/usecases/get_chat_history_usecase.dart';
import '../../domain/usecases/send_message_usecase.dart';
import 'chatbot_event.dart';
import 'chatbot_state.dart';

class ChatbotBloc extends Bloc<ChatbotEvent, ChatbotState> {
  final ChatbotRepository repository;
  final SendMessageUseCase sendMessageUseCase;
  final GetChatHistoryUseCase getChatHistoryUseCase;
  final ClearChatHistoryUseCase clearChatHistoryUseCase;

  ChatbotBloc({
    required this.repository,
    required this.sendMessageUseCase,
    required this.getChatHistoryUseCase,
    required this.clearChatHistoryUseCase,
  }) : super(const ChatbotInitial()) {
    on<InitializeChatbot>(_onInitializeChatbot);
    on<SendMessage>(_onSendMessage);
    on<LoadChatHistory>(_onLoadChatHistory);
    on<ClearChatHistory>(_onClearChatHistory);
    on<UseSuggestedQuestion>(_onUseSuggestedQuestion);
  }

  Future<void> _onInitializeChatbot(
    InitializeChatbot event,
    Emitter<ChatbotState> emit,
  ) async {
    emit(const ChatbotInitializing());

    final result = await repository.initialize();

    result.fold(
      (failure) => emit(ChatbotError(failure.message)),
      (_) {
        // Load chat history after initialization
        add(const LoadChatHistory());
      },
    );
  }

  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<ChatbotState> emit,
  ) async {
    if (state is! ChatbotReady) return;

    final currentMessages = (state as ChatbotReady).messages;

    // Add user message immediately
    final userMessage = ChatMessage.user(event.message);
    final messagesWithUser = [...currentMessages, userMessage];

    // Show loading
    final loadingMessage = ChatMessage.loading();
    emit(ChatbotSending([...messagesWithUser, loadingMessage]));

    // Send message
    final result = await sendMessageUseCase(event.message);

    result.fold(
      (failure) {
        // Remove loading message and show error
        final errorMessage = ChatMessage.error(failure.message);
        emit(ChatbotReady(messages: [...messagesWithUser, errorMessage]));
      },
      (assistantMessage) {
        // Remove loading and add assistant message
        emit(ChatbotReady(messages: [...messagesWithUser, assistantMessage]));
      },
    );
  }

  Future<void> _onLoadChatHistory(
    LoadChatHistory event,
    Emitter<ChatbotState> emit,
  ) async {
    final result = await getChatHistoryUseCase(NoParams());

    result.fold(
      (failure) => emit(ChatbotError(failure.message)),
      (messages) => emit(ChatbotReady(messages: messages)),
    );
  }

  Future<void> _onClearChatHistory(
    ClearChatHistory event,
    Emitter<ChatbotState> emit,
  ) async {
    final result = await clearChatHistoryUseCase(NoParams());

    result.fold(
      (failure) => emit(ChatbotError(failure.message)),
      (_) => emit(const ChatbotReady(messages: [])),
    );
  }

  Future<void> _onUseSuggestedQuestion(
    UseSuggestedQuestion event,
    Emitter<ChatbotState> emit,
  ) async {
    // Same as SendMessage
    add(SendMessage(event.question));
  }
}
