import 'package:flutter/material.dart';

class SuggestedQuestions extends StatelessWidget {
  final Function(String) onQuestionTap;

  const SuggestedQuestions({
    super.key,
    required this.onQuestionTap,
  });

  static const List<Map<String, dynamic>> _questions = [
    {
      'icon': Icons.today,
      'text': 'Thống kê hôm nay',
      'color': Colors.blue,
    },
    {
      'icon': Icons.warning_amber,
      'text': 'Danh sách sách quá hạn',
      'color': Colors.orange,
    },
    {
      'icon': Icons.trending_up,
      'text': 'Top 10 sách phổ biến',
      'color': Colors.green,
    },
    {
      'icon': Icons.library_books,
      'text': 'Tổng quan thư viện',
      'color': Colors.purple,
    },
    {
      'icon': Icons.search,
      'text': 'Tìm sách Lập trình',
      'color': Colors.teal,
    },
    {
      'icon': Icons.people,
      'text': 'Ai đang mượn nhiều sách nhất?',
      'color': Colors.indigo,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Câu hỏi gợi ý',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _questions.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final question = _questions[index];
                return _buildQuestionChip(
                  context,
                  icon: question['icon'] as IconData,
                  text: question['text'] as String,
                  color: question['color'] as Color,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionChip(
    BuildContext context, {
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(text),
      onPressed: () => onQuestionTap(text),
      backgroundColor: Colors.white,
      side: BorderSide(color: color.withOpacity(0.3)),
      labelStyle: const TextStyle(fontSize: 13),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
