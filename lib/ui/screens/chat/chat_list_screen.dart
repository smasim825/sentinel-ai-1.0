import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state.dart';
import 'chat_room_screen.dart';
import 'contact_picker_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please log in to view chats.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Safety Messages", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactPickerScreen()));
        },
        child: const Icon(Icons.add_comment),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: user.uid)
            .snapshots(),
  builder: (context, snapshot) {
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              const Text("Cloud Connection Issue", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                "Error: ${snapshot.error}\n\n"
                "Tip: Ensure you have deployed your Firestore rules and created the necessary composite indexes in the Firebase Console.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final chats = snapshot.data!.docs.where((doc) {
            // Show all chats the user is a part of
            return true;
          }).toList();

          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
                  const SizedBox(height: 24),
                  const Text("No active chats yet.", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("Start a chat with your guardians using the + button.", 
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
            itemBuilder: (context, index) {
              final chatData = chats[index].data() as Map<String, dynamic>;
              final chatId = chats[index].id;
              final lastMsg = chatData['lastMessage'] ?? 'No messages yet';
              
              // Resolve naming for 1-to-1 chats
              String otherUid = "";
              if (chatId.contains('_') && !chatId.startsWith("global_sos")) {
                final parts = chatId.split('_');
                otherUid = parts.first == user.uid ? parts.last : parts.first;
              }

              return FutureBuilder<DocumentSnapshot?>(
                future: otherUid.isEmpty ? Future.value(null) : FirebaseFirestore.instance.collection('users').doc(otherUid).get(),
                builder: (context, userSnap) {
                  String chatName = "Guardian Chat";
                  bool isSOS = chatId.startsWith("global_sos") || lastMsg.contains("🚨 SOS");
                  
                  if (chatId.startsWith("global_sos")) {
                    chatName = "Emergency Dispatch";
                  } else if (userSnap.hasData && userSnap.data!.exists) {
                    final d = userSnap.data!.data() as Map<String, dynamic>;
                    chatName = d['name'] ?? "Guardian Chat";
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: isSOS ? Colors.red : Colors.blueGrey.shade100,
                      child: Icon(isSOS ? Icons.warning : Icons.person, color: isSOS ? Colors.white : Colors.blueGrey),
                    ),
                    title: Text(chatName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        lastMsg, 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: isSOS ? Colors.red.shade700 : Colors.grey.shade600),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ChatRoomScreen(
                          chatId: chatId, 
                          currentUserId: user.uid,
                          otherName: chatName,
                        )
                      ));
                    },
                  );
                }
              );
            },
          );
        },
      ),
    );
  }
}
