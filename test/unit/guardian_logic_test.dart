// Pure Dart test — no Firebase, no Flutter, no plugin dependencies.
// Tests the deterministic chat ID and guardian data logic directly.
import 'package:test/test.dart';

// ── Pure Functions Under Test (copied from ChatService/UserModel) ──────────
String getChatRoomId(String uid1, String uid2) {
  final ids = [uid1, uid2]..sort();
  return ids.join('_');
}

List<String> parseGuardianPhones(dynamic raw) {
  if (raw == null) return [];
  return List<String>.from(raw as List);
}

bool isSosMessage(String text) => text.contains('🚨 SOS ALERT');

// ───────────────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Deterministic Chat Room ID ─────────────────────────────────────────
  group('getChatRoomId — deterministic routing', () {
    test('Same ID whichever uid is first (Alice→Bob = Bob→Alice)', () {
      final id1 = getChatRoomId('alice_uid', 'bob_uid');
      final id2 = getChatRoomId('bob_uid', 'alice_uid');
      expect(id1, equals(id2),
          reason: 'Guardian and User must land in the SAME chat room.');
    });

    test('ID is alphabetically sorted', () {
      final id = getChatRoomId('z_guardian', 'a_user');
      expect(id, startsWith('a_user'),
          reason: 'Lower uid must come first so the ID is always the same.');
    });

    test('Different guardian pairs get DIFFERENT chat rooms', () {
      final chatWithBob     = getChatRoomId('alice_uid', 'bob_uid');
      final chatWithCharlie = getChatRoomId('alice_uid', 'charlie_uid');
      expect(chatWithBob, isNot(equals(chatWithCharlie)),
          reason: 'Each guardian must get a separate private thread.');
    });

    test('Alice with 2 guardians — both routing IDs are correct', () {
      const aliceUid   = 'alice_uid';
      const guardianPhones = ['111', '222'];
      // Simulate resolved UIDs for both guardians
      final guardianUids = {'111': 'bob_uid', '222': 'charlie_uid'};

      final chatIds = guardianPhones
          .map((p) => getChatRoomId(aliceUid, guardianUids[p]!))
          .toList();

      expect(chatIds[0], equals('alice_uid_bob_uid'));
      expect(chatIds[1], equals('alice_uid_charlie_uid'));
      expect(chatIds.toSet().length, equals(2),
          reason: 'Each guardian must have a unique room.');
    });
  });

  // ── 2. Guardian Phone Parsing ──────────────────────────────────────────────
  group('parseGuardianPhones — data integrity', () {
    test('Parses a list of two phones correctly', () {
      final phones = parseGuardianPhones(['+15550002222', '+15550003333']);
      expect(phones.length, equals(2));
      expect(phones[0], equals('+15550002222'));
      expect(phones[1], equals('+15550003333'));
    });

    test('Returns empty list when null (no guardians added yet)', () {
      final phones = parseGuardianPhones(null);
      expect(phones, isEmpty,
          reason: 'Missing guardians field must not crash the SOS flow.');
    });

    test('Each phone is retained as a string (no type coercion)', () {
      final phones = parseGuardianPhones(['01711000000']);
      expect(phones.first, isA<String>());
    });
  });

  // ── 3. SOS Message Detection ───────────────────────────────────────────────
  group('isSosMessage — alert card classification', () {
    test('Detects correctly formatted SOS message', () {
      const msg = '🚨 SOS ALERT! Battery: 72% | Location: https://maps.google.com/...';
      expect(isSosMessage(msg), isTrue);
    });

    test('Regular message is NOT classified as SOS', () {
      const msg = 'Hey, are you okay?';
      expect(isSosMessage(msg), isFalse);
    });

    test('Empty string is NOT an SOS', () {
      expect(isSosMessage(''), isFalse);
    });
  });

  // ── 4. End-to-End SOS Routing Simulation ──────────────────────────────────
  group('Full SOS routing simulation', () {
    test('SOS message is routed to correct guardian chat rooms', () {
      const userUid  = 'user_alice';
      final guardianUidMap = {
        '+111': 'guardian_bob',
        '+222': 'guardian_charlie',
      };

      // Build the SOS message (as SosService would)
      const battery  = 85;
      const location = 'https://maps.google.com/?q=23.7,90.4';
      final message  = '🚨 SOS ALERT! Battery: $battery% | Location: $location';

      // Route to each guardian
      final destinations = guardianUidMap.entries.map((e) {
        final chatId = getChatRoomId(userUid, e.value);
        return {'chatId': chatId, 'message': message};
      }).toList();

      expect(destinations.length, equals(2));

      // Verify both destinations are correct and unique
      final chatIds = destinations.map((d) => d['chatId']!).toSet();
      expect(chatIds.length, equals(2),
          reason: 'Each guardian must receive alert in their own private room.');

      // Verify the message is correctly formatted
      for (final d in destinations) {
        expect(isSosMessage(d['message']!), isTrue,
            reason: 'Every chat alert must be classified as SOS.');
        expect(d['message'], contains('Battery: 85%'));
        expect(d['message'], contains(location));
      }
    });
  });
}
