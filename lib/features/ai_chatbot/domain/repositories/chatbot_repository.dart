import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../data/models/chat_message.dart';

abstract class ChatbotRepository {
  /// Send message and get response
  Future<Either<Failure, ChatMessage>> sendMessage(String message);

  /// Send message with streaming response
  Stream<Either<Failure, String>> sendMessageStream(String message);

  /// Get chat history
  Future<Either<Failure, List<ChatMessage>>> getChatHistory();

  /// Clear chat history
  Future<Either<Failure, void>> clearChatHistory();

  /// Initialize chatbot with system prompt
  Future<Either<Failure, void>> initialize();
}
