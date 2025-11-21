import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../data/models/chat_message.dart';
import '../repositories/chatbot_repository.dart';

class SendMessageUseCase implements UseCase<ChatMessage, String> {
  final ChatbotRepository repository;

  SendMessageUseCase(this.repository);

  @override
  Future<Either<Failure, ChatMessage>> call(String message) async {
    if (message.trim().isEmpty) {
      return Left(ValidationFailure('Tin nhắn không được để trống'));
    }

    return await repository.sendMessage(message);
  }
}
