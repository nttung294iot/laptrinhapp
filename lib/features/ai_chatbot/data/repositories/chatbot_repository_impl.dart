import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/chatbot_repository.dart';
import '../datasources/gemini_api_service.dart';
import '../datasources/library_context_provider.dart';
import '../models/chat_message.dart';

class ChatbotRepositoryImpl implements ChatbotRepository {
  final GeminiApiService _geminiService;
  final LibraryContextProvider _contextProvider;
  final List<ChatMessage> _chatHistory = [];

  ChatbotRepositoryImpl({
    required GeminiApiService geminiService,
    required LibraryContextProvider contextProvider,
  })  : _geminiService = geminiService,
        _contextProvider = contextProvider;

  @override
  Future<Either<Failure, void>> initialize() async {
    try {
      final systemPrompt = await _contextProvider.getSystemPrompt();
      _geminiService.initializeChatSession(systemPrompt);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Không thể khởi tạo chatbot: $e'));
    }
  }

  @override
  Future<Either<Failure, ChatMessage>> sendMessage(String message) async {
    try {
      // Add user message to history
      final userMessage = ChatMessage.user(message);
      _chatHistory.add(userMessage);

      // Get context for the query
      final context = await _contextProvider.getContextForQuery(message);

      // Send to Gemini with context
      final response = await _geminiService.sendMessageWithContext(message, context);

      // Create assistant message
      final assistantMessage = ChatMessage.assistant(
        response,
        metadata: {'context': context},
      );
      _chatHistory.add(assistantMessage);

      return Right(assistantMessage);
    } catch (e) {
      final errorMessage = ChatMessage.error(e.toString());
      _chatHistory.add(errorMessage);
      return Left(ServerFailure('Lỗi khi gửi tin nhắn: $e'));
    }
  }

  @override
  Stream<Either<Failure, String>> sendMessageStream(String message) async* {
    try {
      // Add user message to history
      final userMessage = ChatMessage.user(message);
      _chatHistory.add(userMessage);

      // Get context
      final context = await _contextProvider.getContextForQuery(message);

      // Stream response
      final responseStream = _geminiService.sendMessageStream(message);
      
      String fullResponse = '';
      await for (final chunk in responseStream) {
        fullResponse += chunk;
        yield Right(chunk);
      }

      // Add complete response to history
      final assistantMessage = ChatMessage.assistant(
        fullResponse,
        metadata: {'context': context},
      );
      _chatHistory.add(assistantMessage);
    } catch (e) {
      yield Left(ServerFailure('Lỗi khi gửi tin nhắn: $e'));
    }
  }

  @override
  Future<Either<Failure, List<ChatMessage>>> getChatHistory() async {
    try {
      return Right(List.from(_chatHistory));
    } catch (e) {
      return Left(CacheFailure('Không thể lấy lịch sử chat: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> clearChatHistory() async {
    try {
      _chatHistory.clear();
      
      // Reinitialize chat session
      final systemPrompt = await _contextProvider.getSystemPrompt();
      _geminiService.resetChat(systemPrompt);
      
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Không thể xóa lịch sử chat: $e'));
    }
  }
}
