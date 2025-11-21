import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../data/models/chat_message.dart';
import '../repositories/chatbot_repository.dart';

class GetChatHistoryUseCase implements UseCase<List<ChatMessage>, NoParams> {
  final ChatbotRepository repository;

  GetChatHistoryUseCase(this.repository);

  @override
  Future<Either<Failure, List<ChatMessage>>> call(NoParams params) async {
    return await repository.getChatHistory();
  }
}
