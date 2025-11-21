import 'package:equatable/equatable.dart';

abstract class ChatbotEvent extends Equatable {
  const ChatbotEvent();

  @override
  List<Object?> get props => [];
}

class InitializeChatbot extends ChatbotEvent {
  const InitializeChatbot();
}

class SendMessage extends ChatbotEvent {
  final String message;

  const SendMessage(this.message);

  @override
  List<Object?> get props => [message];
}

class LoadChatHistory extends ChatbotEvent {
  const LoadChatHistory();
}

class ClearChatHistory extends ChatbotEvent {
  const ClearChatHistory();
}

class UseSuggestedQuestion extends ChatbotEvent {
  final String question;

  const UseSuggestedQuestion(this.question);

  @override
  List<Object?> get props => [question];
}
