import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/gemini_api_service.dart';
import '../../data/datasources/library_context_provider.dart';
import '../../data/models/chat_message.dart';
import '../../data/repositories/chatbot_repository_impl.dart';
import '../../domain/usecases/clear_chat_history_usecase.dart';
import '../../domain/usecases/get_chat_history_usecase.dart';
import '../../domain/usecases/send_message_usecase.dart';
import '../bloc/chatbot_bloc.dart';
import '../bloc/chatbot_event.dart';
import '../bloc/chatbot_state.dart';
import '../widgets/chat_message_list.dart';
import '../widgets/chat_input_field.dart';
import '../widgets/suggested_questions.dart';

class AiChatbotScreen extends StatelessWidget {
  const AiChatbotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final geminiService = GeminiApiService();
        final contextProvider = LibraryContextProvider();
        final repository = ChatbotRepositoryImpl(
          geminiService: geminiService,
          contextProvider: contextProvider,
        );

        return ChatbotBloc(
          repository: repository,
          sendMessageUseCase: SendMessageUseCase(repository),
          getChatHistoryUseCase: GetChatHistoryUseCase(repository),
          clearChatHistoryUseCase: ClearChatHistoryUseCase(repository),
        )..add(const InitializeChatbot());
      },
      child: const _AiChatbotView(),
    );
  }
}

class _AiChatbotView extends StatelessWidget {
  const _AiChatbotView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'AI Trợ lý Thủ thư',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Xóa lịch sử chat',
            onPressed: () => _showClearHistoryDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Hướng dẫn',
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<ChatbotBloc, ChatbotState>(
        builder: (context, state) {
          if (state is ChatbotInitializing) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang khởi tạo AI Chatbot...'),
                ],
              ),
            );
          }

          if (state is ChatbotError && state.messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Lỗi: ${state.message}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<ChatbotBloc>().add(const InitializeChatbot());
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final messages = state is ChatbotReady
              ? (state as ChatbotReady).messages
              : state is ChatbotSending
                  ? (state as ChatbotSending).messages
                  : state is ChatbotError
                      ? (state as ChatbotError).messages
                      : <ChatMessage>[];

          return Column(
            children: [
              // Chat messages
              Expanded(
                child: messages.isEmpty
                    ? _buildEmptyState(context)
                    : ChatMessageList(messages: messages),
              ),

              // Suggested questions (only show when empty)
              if (messages.isEmpty)
                SuggestedQuestions(
                  onQuestionTap: (question) {
                    context.read<ChatbotBloc>().add(UseSuggestedQuestion(question));
                  },
                ),

              // Input field
              ChatInputField(
                onSend: (message) {
                  context.read<ChatbotBloc>().add(SendMessage(message));
                },
                enabled: state is ChatbotReady || state is ChatbotError,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy,
                size: 64,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Xin chào! 👋',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tôi là AI Trợ lý Thủ thư',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const Text(
              'Tôi có thể giúp bạn:\n'
              '• Tra cứu thông tin sách, độc giả\n'
              '• Thống kê phiếu mượn, quá hạn\n'
              '• Gợi ý xử lý công việc\n'
              '• Tạo báo cáo nhanh',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'Hãy chọn câu hỏi gợi ý bên dưới\nhoặc nhập câu hỏi của bạn! 💬',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa lịch sử chat'),
        content: const Text(
          'Bạn có chắc muốn xóa toàn bộ lịch sử chat?\n'
          'Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              context.read<ChatbotBloc>().add(const ClearChatHistory());
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã xóa lịch sử chat')),
              );
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline),
            SizedBox(width: 8),
            Text('Hướng dẫn sử dụng'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Câu hỏi mẫu:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('📊 Thống kê:\n'
                  '• "Hôm nay có bao nhiêu phiếu mượn?"\n'
                  '• "Sách nào được mượn nhiều nhất?"\n'
                  '• "Có bao nhiêu sách quá hạn?"'),
              SizedBox(height: 12),
              Text('🔍 Tra cứu:\n'
                  '• "Độc giả SV001 đang mượn sách gì?"\n'
                  '• "Sách Flutter còn mấy cuốn?"\n'
                  '• "Tìm sách về lập trình"'),
              SizedBox(height: 12),
              Text('💡 Gợi ý:\n'
                  '• "Nên làm gì với phiếu quá hạn?"\n'
                  '• "Sách nào nên nhập thêm?"'),
              SizedBox(height: 12),
              Text('📈 Báo cáo:\n'
                  '• "Tạo báo cáo tuần này"\n'
                  '• "Thống kê theo thể loại"'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
