import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/chat_service.dart';
import 'package:sentinel/models/user_model.dart';

void main() {
  group('Guardian Connection Simulation', () {
    final chatService = ChatService();

    test('Should simulate SOS routing to multiple guardians', () async {
      // 1. Setup User Alice
      final alice = UserModel(
        uid: "alice_uid",
        name: "Alice",
        email: "alice@safety.com",
        phone: "111",
        guardianPhones: ["222", "333"], // Bob and Charlie
        role: "User",
      );

      // 2. Setup Guardians
      const bobUid = "bob_uid";
      const charlieUid = "charlie_uid";

      // 3. Verify Deterministic IDs for both guardians
      final chatWithBob = chatService.getChatRoomId(alice.uid, bobUid);
      final chatWithCharlie = chatService.getChatRoomId(alice.uid, charlieUid);

      expect(chatWithBob, contains("alice_uid"));
      expect(chatWithBob, contains("bob_uid"));
      expect(chatWithCharlie, contains("alice_uid"));
      expect(chatWithCharlie, contains("charlie_uid"));
      expect(chatWithBob, isNot(equals(chatWithCharlie)));

      // 4. Verify that the order doesn't matter for the guardian either
      final bobPerspectiveId = chatService.getChatRoomId(bobUid, alice.uid);
      expect(bobPerspectiveId, equals(chatWithBob), 
        reason: "Guardian must see the exact same Chat Room ID as the User to communicate.");
    });
  });
}
