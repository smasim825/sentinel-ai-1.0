import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/models/user_model.dart';

void main() {
  group('UserModel Parsing Tests', () {
    test('fromMap should correctly parse guardianPhones list', () {
      final data = {
        'name': 'Test User',
        'email': 'test@example.com',
        'phone': '1234567890',
        'guardianPhones': ['9876543210', '5556667777'],
        'role': 'User',
      };
      
      final user = UserModel.fromMap(data, 'test_uid');
      
      expect(user.uid, equals('test_uid'));
      expect(user.name, equals('Test User'));
      expect(user.guardianPhones.length, equals(2));
      expect(user.guardianPhones[0], equals('9876543210'));
      expect(user.guardianPhones[1], equals('5556667777'));
    });

    test('toMap should produce expected map structure', () {
      final user = UserModel(
        uid: 'uid_1',
        name: 'Alice',
        email: 'alice@test.com',
        phone: '111',
        guardianPhones: ['222'],
        role: 'Guardian',
      );

      final map = user.toMap();
      expect(map['name'], equals('Alice'));
      expect(map['guardianPhones'], isA<List<String>>());
      expect(map['guardianPhones'][0], equals('222'));
      expect(map['role'], equals('Guardian'));
    });
  });
}
