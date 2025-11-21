# 🤖 AI Chatbot Trợ lý Thủ thư

## Tính năng

- ✅ Trả lời câu hỏi thống kê (phiếu mượn, sách, độc giả)
- ✅ Tra cứu thông tin (độc giả, sách)
- ✅ Gợi ý hành động xử lý
- ✅ Tạo báo cáo nhanh
- ✅ Hỗ trợ tiếng Việt
- ✅ UI đẹp với Markdown support
- ✅ Câu hỏi gợi ý
- ✅ Lịch sử chat

## Cài đặt

### 1. Thêm dependencies vào `pubspec.yaml`:

```yaml
dependencies:
  # AI & ML
  google_generative_ai: ^0.2.2
  
  # UI
  flutter_markdown: ^0.6.18
  
  # Existing dependencies
  flutter_bloc: ^8.1.3
  equatable: ^2.0.5
  dartz: ^0.10.1
  intl: ^0.18.1
```

### 2. Chạy lệnh:

```bash
flutter pub get
```

### 3. Thêm route vào app:

Trong file `lib/main.dart` hoặc router, thêm:

```dart
import 'package:your_app/features/ai_chatbot/presentation/screens/ai_chatbot_screen.dart';

// Trong routes:
'/ai-chatbot': (context) => const AiChatbotScreen(),
```

### 4. Thêm button để mở chatbot:

```dart
FloatingActionButton(
  onPressed: () {
    Navigator.pushNamed(context, '/ai-chatbot');
  },
  child: const Icon(Icons.smart_toy),
  tooltip: 'AI Trợ lý',
)
```

## Sử dụng

### Câu hỏi mẫu:

**📊 Thống kê:**
- "Hôm nay có bao nhiêu phiếu mượn?"
- "Sách nào được mượn nhiều nhất tuần này?"
- "Có bao nhiêu sách quá hạn?"

**🔍 Tra cứu:**
- "Độc giả SV001 đang mượn sách gì?"
- "Sách Flutter còn mấy cuốn?"
- "Tìm sách về lập trình"

**💡 Gợi ý:**
- "Nên làm gì với phiếu quá hạn?"
- "Sách nào nên nhập thêm?"

**📈 Báo cáo:**
- "Tạo báo cáo tuần này"
- "Thống kê theo thể loại"

## API Key

API key Gemini đã được cấu hình trong file:
`lib/features/ai_chatbot/data/datasources/gemini_api_service.dart`

**Lưu ý:** Trong production, nên move API key ra environment variable.

## Kiến trúc

```
ai_chatbot/
├── data/
│   ├── datasources/
│   │   ├── gemini_api_service.dart          # Gọi Gemini API
│   │   └── library_context_provider.dart    # Lấy context từ database
│   ├── models/
│   │   └── chat_message.dart                # Model tin nhắn
│   └── repositories/
│       └── chatbot_repository_impl.dart     # Implementation
├── domain/
│   ├── repositories/
│   │   └── chatbot_repository.dart          # Interface
│   └── usecases/
│       ├── send_message_usecase.dart
│       ├── get_chat_history_usecase.dart
│       └── clear_chat_history_usecase.dart
└── presentation/
    ├── bloc/
    │   ├── chatbot_bloc.dart
    │   ├── chatbot_event.dart
    │   └── chatbot_state.dart
    ├── screens/
    │   └── ai_chatbot_screen.dart           # Main screen
    └── widgets/
        ├── chat_message_list.dart
        ├── chat_message_bubble.dart
        ├── chat_input_field.dart
        └── suggested_questions.dart
```

## Troubleshooting

### Lỗi: "API key not valid"
- Kiểm tra API key trong `gemini_api_service.dart`
- Đảm bảo API key còn hạn sử dụng
- Kiểm tra quota tại: https://makersuite.google.com/

### Lỗi: "Cannot connect to database"
- Kiểm tra kết nối PostgreSQL
- Đảm bảo `DatabaseHelper` đã được khởi tạo
- Kiểm tra credentials trong `database_config.dart`

### Chatbot trả lời không chính xác
- Kiểm tra `LibraryContextProvider` có lấy đúng data không
- Xem logs để debug context được gửi cho AI
- Có thể cần cải thiện system prompt

## Tối ưu

### Giảm chi phí API:
- Cache responses cho câu hỏi phổ biến
- Implement rate limiting
- Sử dụng streaming để UX tốt hơn

### Cải thiện độ chính xác:
- Fine-tune system prompt
- Thêm examples vào prompt
- Validate responses trước khi hiển thị

## Demo

Xem video demo tại: [Link video]

## License

MIT License
