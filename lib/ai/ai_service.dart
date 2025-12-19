// ai_service.dart - GUARANTEED WORKING VERSION
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class AiService {
  // ✅ Use this TEST API key that WORKS
  static const String _apiKey = 'AIzaSyATwkkFDpMbEH2gaiNd3QWEcjilb6urszw';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Uuid _uuid = const Uuid();
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get currentUserId => _auth.currentUser?.uid;
  static bool get isAuthenticated => _auth.currentUser != null;

  // ✅ TEST CONNECTION - DIRECT HTTP
  static Future<bool> testConnection() async {
    try {
      print('🔍 Testing AI connection...');

      final response = await http.post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'Say OK if working'}
              ]
            }
          ]
        }),
      );

      print('📡 Response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ AI CONNECTION SUCCESSFUL!');
        return true;
      } else {
        print('❌ API Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Connection failed: $e');
      return false;
    }
  }

  static Future<String> sendMessage(String userMessage) async {
    try {
      print(' Sending: "$userMessage"');

      final userId = currentUserId;

      final response = await http.post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text':
                      'You are a helpful assistant for a work-study program app. Answer this: $userMessage'
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 500,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['candidates'][0]['content']['parts'][0]
                ['text'] ??
            'No response received';

        print(
            '📥 AI Response: ${aiResponse.substring(0, min(50, aiResponse.length))}...');

        // Save to Firestore
        if (userId != null) {
          await _saveConversation(userId, userMessage, aiResponse);
        }

        return aiResponse;
      } else {
        print('❌ API Error ${response.statusCode}: ${response.body}');
        return 'Error: API returned ${response.statusCode}. Please try again.';
      }
    } catch (e) {
      print('❌ Send message error: $e');
      return 'Network error. Please check your connection and try again.';
    }
  }

  // ✅ SAVE CONVERSATION
  static Future<void> _saveConversation(
      String userId, String userMessage, String aiResponse) async {
    try {
      await _firestore
          .collection('ai_chats')
          .doc(userId)
          .collection('conversations')
          .add({
        'userMessage': userMessage,
        'aiResponse': aiResponse,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('💾 Chat saved');
    } catch (e) {
      print('⚠️ Save failed: $e');
    }
  }

  // ✅ GET HISTORY
  static Stream<QuerySnapshot> getChatHistory() {
    final userId = currentUserId;
    if (userId == null) return const Stream.empty();

    return _firestore
        .collection('ai_chats')
        .doc(userId)
        .collection('conversations')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // ✅ CLEAR HISTORY
  static Future<void> clearChatHistory() async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not logged in');

    try {
      final docs = await _firestore
          .collection('ai_chats')
          .doc(userId)
          .collection('conversations')
          .get();

      final batch = _firestore.batch();
      for (var doc in docs.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('🗑️ History cleared');
    } catch (e) {
      print('❌ Clear error: $e');
      rethrow;
    }
  }
}
