import 'package:equatable/equatable.dart';

enum MessageRole {
  user,
  assistant,
  system;

  String toJson() => name;

  static MessageRole fromJson(String value) {
    return MessageRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageRole.user,
    );
  }
}

class ChatMessage extends Equatable {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? metadata; // Để lưu thêm thông tin (charts, data, etc.)

  const ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.isLoading = false,
    this.error,
    this.metadata,
  });

  factory ChatMessage.user(String content) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );
  }

  factory ChatMessage.assistant(String content, {Map<String, dynamic>? metadata}) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  factory ChatMessage.loading() {
    return ChatMessage(
      id: 'loading',
      content: '',
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      isLoading: true,
    );
  }

  factory ChatMessage.error(String error) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: 'Xin lỗi, đã có lỗi xảy ra: $error',
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      error: error,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? content,
    MessageRole? role,
    DateTime? timestamp,
    bool? isLoading,
    String? error,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'role': role.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'isLoading': isLoading,
      'error': error,
      'metadata': metadata,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      role: MessageRole.fromJson(json['role'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isLoading: json['isLoading'] as bool? ?? false,
      error: json['error'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [id, content, role, timestamp, isLoading, error, metadata];
}
