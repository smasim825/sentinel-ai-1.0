import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state.dart';
import '../../../services/chat_service.dart';
import 'chat_room_screen.dart';

class ContactPickerScreen extends StatefulWidget {
  const ContactPickerScreen({super.key});

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen> {
  final ChatService _chatService = ChatService();
  bool _isLoading = true;
  List<Map<String, String>> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final user = context.read<AppState>().currentUser;
    if (user == null) return;

    List<Map<String, String>> resolved = [];

    for (String phone in user.guardianPhones) {
      final uid = await _chatService.getUserByPhone(phone);
      if (uid != null) {
        resolved.add({
          'name': 'Guardian ($phone)',
          'phone': phone,
          'uid': uid,
        });
      } else {
        resolved.add({
          'name': 'Guardian ($phone)',
          'phone': phone,
          'uid': '', // Not on Sentinel
        });
      }
    }

    if (mounted) {
      setState(() {
        _contacts = resolved;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Contact")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? const Center(child: Text("No guardians added yet. Please add them in Profile."))
              : ListView.builder(
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    final bool isOnSentinel = contact['uid']!.isNotEmpty;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isOnSentinel ? Colors.green : Colors.grey,
                        child: Icon(isOnSentinel ? Icons.person : Icons.person_off, color: Colors.white),
                      ),
                      title: Text(contact['name']!),
                      subtitle: Text(isOnSentinel ? "On Sentinel" : "Not registered"),
                      trailing: isOnSentinel ? const Icon(Icons.chat, color: Colors.blue) : null,
                          onTap: isOnSentinel
                              ? () async {
                                  final user = context.read<AppState>().currentUser!;
                                  final chatId = _chatService.getChatRoomId(user.uid, contact['uid']!);
                                  
                                  // Pre-initialize chat so other user has permission immediately
                                  await _chatService.initializeChat(chatId, user.uid, contact['uid']!);

                                  if (mounted) {
                                    Navigator.pushReplacement(context, MaterialPageRoute(
                                      builder: (_) => ChatRoomScreen(
                                        chatId: chatId,
                                        currentUserId: user.uid,
                                        otherName: contact['name'],
                                      ),
                                    ));
                                  }
                                }
                              : null,
                    );
                  },
                ),
    );
  }
}
