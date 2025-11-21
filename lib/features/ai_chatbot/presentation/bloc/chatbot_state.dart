import 'package:equatable/equatable.dart';
import '../../data/models/chat_message.dart';

abstract class ChatbotState extends Equatable {
  const ChatbotState();

  @override
  List<Object?> get props => [];
}

class ChatbotInitial extends ChatbotState {
  const ChatbotInitial();
}

class ChatbotInitializing extends ChatbotState {
  const ChatbotInitializing();
}

class ChatbotReady extends ChatbotState {
  final List<ChatMessage> messages;

  const ChatbotReady({this.messages = const []});

  @override
  List<Object?> get props => [messages];

  ChatbotReady copyWith({List<ChatMessage>? messages}) {
    return ChatbotReady(
      messages: messages ?? this.messages,
    );
  }
}

class ChatbotSending extends ChatbotState {
  final List<ChatMessage> messages;

  const ChatbotSending(this.messages);

  @override
  List<Object?> get props => [messages];
}

class ChatbotError extends ChatbotState {
  final String message;
  final List<ChatMessage> messages;

  const ChatbotError(this.message, {this.messages = const []});

  @override
  List<Object?> get props => [message, messages];
}
