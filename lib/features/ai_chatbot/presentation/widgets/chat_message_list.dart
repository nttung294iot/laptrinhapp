import 'package:flutter/material.dart';
import '../../data/models/chat_message.dart';
import 'chat_message_bubble.dart';

class ChatMessageList extends StatefulWidget {
  final List<ChatMessage> messages;

  const ChatMessageList({
    super.key,
    required this.messages,
  });

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      // Scroll to bottom when new message arrives
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: widget.messages.length,
      itemBuilder: (context, index) {
        final message = widget.messages[index];
        return ChatMessageBubble(
          message: message,
          isFirstInGroup: index == 0 ||
              widget.messages[index - 1].role != message.role,
          isLastInGroup: index == widget.messages.length - 1 ||
              widget.messages[index + 1].role != message.role,
        );
      },
    );
  }
}
