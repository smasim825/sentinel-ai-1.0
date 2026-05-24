import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/chat_service.dart';

void main() {
  group('ChatService Logic Tests', () {
    // We pass null for firestore because getChatRoomId doesn't use it.
    // This avoids triggering the FirebaseFirestore.instance hang.
    final chatService = ChatService(firestore: null);

    test('getChatRoomId should be deterministic (same ID regardless of order)', () {
      const uid1 = "alice_123";
      const uid2 = "bob_456";

      final id1 = chatService.getChatRoomId(uid1, uid2);
      final id2 = chatService.getChatRoomId(uid2, uid1);

      expect(id1, equals(id2));
      expect(id1, contains(uid1));
      expect(id1, contains(uid2));
      expect(id1, equals("alice_123_bob_456")); 
    });

    test('getChatRoomId should result in alphabetical sorting', () {
      const uidA = "a_user";
      const uidZ = "z_user";

      final id = chatService.getChatRoomId(uidZ, uidA);
      expect(id, equals("a_user_z_user"));
    });
  });
}
