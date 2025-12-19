import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_messages.dart';
import 'chat_input.dart';
import 'ai_service.dart';

// Import the global key from main.dart
import '../main.dart';

class AiChatSheet extends StatefulWidget {
  const AiChatSheet({super.key});

  @override
  State<AiChatSheet> createState() => _AiChatSheetState();
}

class _AiChatSheetState extends State<AiChatSheet> {
  bool _isLoading = false;
  final User? _user = FirebaseAuth.instance.currentUser;

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Check authentication
    if (!AiService.isAuthenticated) {
      _showLoginPrompt();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await AiService.sendMessage(text);
      // ChatMessages widget will auto-update via stream
      print('✅ Message sent and saved');
    } catch (e) {
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showLoginPrompt() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please login to save chat history'),
        action: SnackBarAction(
          label: 'Login',
          onPressed: () {
            Navigator.pop(context); // Close the AI sheet
            // Use the global navigator key for navigation
            navigatorKey.currentState?.pushNamed('/login');
          },
        ),
      ),
    );
  }

  Future<void> _clearHistory() async {
    if (!AiService.isAuthenticated) {
      _showLoginPrompt();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AiService.clearChatHistory();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat history cleared'),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing history: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.smart_toy_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "WorkStudy Assistant",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_user != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white),
                        tooltip: 'Clear History',
                        onPressed: _clearHistory,
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Authentication Status
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color:
                    _user != null ? Colors.green.shade50 : Colors.amber.shade50,
                child: Row(
                  children: [
                    Icon(
                      _user != null ? Icons.verified : Icons.info,
                      color: _user != null ? Colors.green : Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _user != null
                            ? 'Chats will be saved to your account'
                            : 'Login to save chat history',
                        style: TextStyle(
                          fontSize: 12,
                          color: _user != null
                              ? Colors.green.shade800
                              : Colors.amber.shade800,
                        ),
                      ),
                    ),
                    if (_user == null)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // Close the AI sheet
                          navigatorKey.currentState?.pushNamed('/login');
                        },
                        child: Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Messages
              Expanded(
                child: ChatMessages(
                  // ChatMessages will handle the stream internally
                  key:
                      ValueKey(_user?.uid ?? 'guest'), // Rebuild on user change
                ),
              ),

              // Loading indicator
              if (_isLoading)
                Container(
                  padding: const EdgeInsets.all(8),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Thinking...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

              // Input
              ChatInput(
                onSendMessage: _sendMessage,
                isLoading: _isLoading,
              ),
            ],
          ),
        );
      },
    );
  }
}
