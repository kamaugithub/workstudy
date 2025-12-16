import 'package:flutter/material.dart';
import '../ai/ai_chat_sheet.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => const AiChatSheet(),
          );
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.smart_toy_rounded),
      ),
    );
  }
}
