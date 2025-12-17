import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class AiService {
  // 🔥 REPLACE THIS WITH YOUR ACTUAL GEMINI API KEY
  static const String _apiKey = 'AIzaSyDwK6uZHA4BB5iNm6aXqojEIEE8xlxYa-s';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Uuid _uuid = const Uuid();
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔥 CHOOSE ONE OF THESE MODELS (they're all valid):
  static final GenerativeModel _model = GenerativeModel(
    // Use a stable, explicit version
    model: 'gemini-2.5-flash-001', // or 'gemini-2.5-flash'
    apiKey: _apiKey,
    generationConfig: GenerationConfig(
      maxOutputTokens: 500,
      temperature: 0.7,
      topP: 0.8,
    ),
  );

  // Get current user ID safely
  static String? get currentUserId {
    return _auth.currentUser?.uid;
  }

  // Check if user is authenticated
  static bool get isAuthenticated {
    return _auth.currentUser != null;
  }

  // Test the API key and model
  static Future<bool> testConnection() async {
    try {
      final model = GenerativeModel(
        // This should be the same model name you are using above
        model: 'gemini-2.5-flash-001',
        apiKey: _apiKey,
      );
      final chat = model.startChat();
      final response = await chat.sendMessage(Content.text('Hello'));
      return response.text != null;
    } catch (e) {
      print('❌ AI Connection Test Failed: $e');
      return false;
    }
  }

  // Send message to AI and save to Firestore
  static Future<String> sendMessage(String userMessage) async {
    try {
      final userId = currentUserId;

      // Validate authentication
      if (userId == null) {
        return "Please login to save your chat history. Your message: '$userMessage'";
      }

      // Create system prompt for work-study context
      final systemPrompt = """
      You are a helpful Work-Study Assistant for a university work-study program.
      You help students, supervisors, and administrators with:
      1. Work-study application questions
      2. Time tracking and approvals
      3. Supervisor queries
      4. Administrative procedures
      5. Schedule management
      
      Be professional, concise, and helpful.
      If you don't know something, suggest contacting the work-study office.
      """;

      final chat = _model.startChat(
        history: [
          Content.text(systemPrompt),
          Content.model([
            TextPart(
                'Hello! I\'m your Work-Study Assistant. How can I help you today?')
          ]),
        ],
      );

      final response = await chat.sendMessage(Content.text(userMessage));
      final aiResponse =
          response.text ?? 'I apologize, I could not process that request.';

      // Save conversation to Firestore
      await _saveConversation(userId, userMessage, aiResponse);

      return aiResponse;
    } catch (e) {
      print('❌ AI Error: $e');

      // Helpful error messages
      if (e.toString().contains('API key')) {
        return 'AI service configuration error. Please check API key setup.';
      } else if (e.toString().contains('permission-denied')) {
        return 'Unable to save chat. Please ensure you are logged in.';
      } else if (e.toString().contains('network')) {
        return 'Network error. Please check your internet connection.';
      }

      return 'I\'m having trouble connecting to the AI service. Please try again in a moment.';
    }
  }

  // Save conversation to Firestore
  static Future<void> _saveConversation(
      String userId, String userMessage, String aiResponse) async {
    try {
      final conversationId = _uuid.v4();
      final timestamp = DateTime.now();

      await _firestore
          .collection('ai_chats')
          .doc(userId)
          .collection('conversations')
          .doc(conversationId)
          .set({
        'userMessage': userMessage,
        'aiResponse': aiResponse,
        'timestamp': timestamp,
        'conversationId': conversationId,
      });

      print('✅ Chat saved successfully for user: $userId');
    } catch (e) {
      print('❌ Firestore save error: $e');
      rethrow;
    }
  }

  // Load chat history for current user
  static Stream<QuerySnapshot> getChatHistory() {
    final userId = currentUserId;

    if (userId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('ai_chats')
        .doc(userId)
        .collection('conversations')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots();
  }

  // Clear chat history for current user
  static Future<void> clearChatHistory() async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final batch = _firestore.batch();
      final chats = await _firestore
          .collection('ai_chats')
          .doc(userId)
          .collection('conversations')
          .get();

      for (var doc in chats.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('✅ Chat history cleared for user: $userId');
    } catch (e) {
      print('❌ Clear history error: $e');
      rethrow;
    }
  }
}
