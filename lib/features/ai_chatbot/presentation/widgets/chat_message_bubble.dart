import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../data/models/chat_message.dart';
import 'package:intl/intl.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final isLoading = message.isLoading;

    return Padding(
      padding: EdgeInsets.only(
        top: isFirstInGroup ? 8 : 2,
        bottom: isLastInGroup ? 8 : 2,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar(context, isUser),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Theme.of(context).primaryColor
                        : Colors.grey[200],
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isUser || !isFirstInGroup ? 16 : 4),
                      topRight: Radius.circular(!isUser || !isFirstInGroup ? 16 : 4),
                      bottomLeft: const Radius.circular(16),
                      bottomRight: const Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isLoading
                      ? _buildLoadingIndicator()
                      : _buildMessageContent(context, isUser),
                ),
                if (isLastInGroup) ...[
                  const SizedBox(height: 4),
                  _buildTimestamp(context),
                ],
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(context, isUser),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, bool isUser) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isUser
            ? Theme.of(context).primaryColor
            : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        size: 20,
        color: isUser ? Colors.white : Colors.grey[700],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, bool isUser) {
    return InkWell(
      onLongPress: () => _showMessageOptions(context),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: isUser
            ? Text(
                message.content,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              )
            : MarkdownBody(
                data: message.content,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 15, color: Colors.black87),
                  strong: const TextStyle(fontWeight: FontWeight.bold),
                  em: const TextStyle(fontStyle: FontStyle.italic),
                  code: TextStyle(
                    backgroundColor: Colors.grey[300],
                    fontFamily: 'monospace',
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Đang suy nghĩ...'),
        ],
      ),
    );
  }

  Widget _buildTimestamp(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        timeFormat.format(message.timestamp),
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Sao chép'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép tin nhắn')),
                );
              },
            ),
            if (message.role == MessageRole.assistant)
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Chia sẻ'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement share functionality
                },
              ),
          ],
        ),
      ),
    );
  }
}
