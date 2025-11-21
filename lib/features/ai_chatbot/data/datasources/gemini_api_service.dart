import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiApiService {
  static const String _apiKey = 'AIzaSyCFcdEzBvEoq5QUwiCRnfixmifa5rNg4Eg';
  
  late final GenerativeModel _model;
  late final ChatSession _chatSession;

  GeminiApiService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 64,
        topP: 0.95,
        maxOutputTokens: 8129,
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
      ],
    );
  }

  /// Initialize chat session with system prompt
  void initializeChatSession(String systemPrompt) {
    _chatSession = _model.startChat(
      history: [
        Content.text(systemPrompt),
      ],
    );
  }

  /// Send message and get response
  Future<String> sendMessage(String message) async {
    try {
      final response = await _chatSession.sendMessage(
        Content.text(message),
      );
      
      return response.text ?? 'Xin lỗi, tôi không thể trả lời câu hỏi này.';
    } catch (e) {
      throw Exception('Lỗi khi gọi Gemini API: $e');
    }
  }

  /// Send message with context (for one-off queries)
  Future<String> sendMessageWithContext(String message, String context) async {
    try {
      final prompt = '''
$context

User: $message
Assistan
t: Hãy trả lời câu hỏi dựa trên context trên.
''';

      final response = await _model.generateContent([
        Content.text(prompt),
      ]);

      return response.text ?? 'Xin lỗi, tôi không thể trả lời câu hỏi này.';
    } catch (e) {
      throw Exception('Lỗi khi gọi Gemini API: $e');
    }
  }

  /// Generate content with streaming
  Stream<String> sendMessageStream(String message) async* {
    try {
      final response = _chatSession.sendMessageStream(
        Content.text(message),
      );

      await for (final chunk in response) {
        if (chunk.text != null) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      yield 'Lỗi: $e';
    }
  }

  /// Reset chat session
  void resetChat(String systemPrompt) {
    initializeChatSession(systemPrompt);
  }
}
