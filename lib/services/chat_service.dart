import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/message_model.dart';

import '../services/auth_service.dart';

class ChatService {
  final FirebaseFirestore _firestore;

  ChatService({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Deterministic way to generate a chat ID for two users.
  /// Always sorts UIDs alphabetically so User A -> User B is the same ID as User B -> User A.
  String getChatRoomId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort();
    return ids.join('_');
  }

  /// Ensure a chat document exists between two users.
  Future<void> initializeChat(String chatId, String userId1, String userId2, {bool isMonitoring = false}) async {
    await _firestore.collection('chats').doc(chatId).set({
      'lastMessage': 'Chat started',
      'lastTimestamp': FieldValue.serverTimestamp(),
      'participants': [userId1, userId2],
      'isMonitoringActive': isMonitoring,
      'guardianUid': userId2, // The one who IS the guardian
    }, SetOptions(merge: true));
  }

  Future<void> setChatMonitoringActive(String chatId, bool active) async {
    await _firestore.collection('chats').doc(chatId).update({
      'isMonitoringActive': active,
    });
  }

  /// Resolve a phone number to a User UID. Useful for starting chats with guardians.
  Future<String?> getUserByPhone(String phone) async {
    try {
      final normalized = AuthService.normalizePhone(phone);
      final snapshot = await _firestore
          .collection('users')
          .where('phone', isEqualTo: normalized)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
    } catch (e) {
      print("Error finding user by phone: $e");
    }
    return null;
  }

  Stream<List<MessageModel>> getChatStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => MessageModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> sendMessage(String chatId, String senderId, String text, {String? imageUrl}) async {
    final displayMsg = imageUrl != null ? "📷 Photo" : text;
    if (text.trim().isEmpty && imageUrl == null) return;
    
    // Ensure the chat document exists and participants are correctly set
    // We get the participants by splitting the chatId which is always [uid1]_[uid2]
    final participants = chatId.split('_');
    
    await _firestore.collection('chats').doc(chatId).set({
      'lastMessage': displayMsg,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'participants': FieldValue.arrayUnion(participants), 
    }, SetOptions(merge: true));

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': senderId,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Uploads media (image/video) to storage.
  Future<String?> uploadChatMedia(String chatId, Uint8List fileBytes, String extension) async {
    try {
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.$extension";
      final ref = FirebaseStorage.instance.ref().child('chats/$chatId/$fileName');
      final contentType = extension == 'mp4' ? 'video/mp4' : 'image/jpeg';
      await ref.putData(fileBytes, SettableMetadata(contentType: contentType));
      return await ref.getDownloadURL();
    } catch (e) {
      print("Upload error: $e");
      return null;
    }
  }

  /// Delete a specific message for all participants.
  Future<void> deleteMessage(String chatId, String messageId) async {
    // Check if this is the last message to keep chat list in sync
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    if (chatDoc.exists) {
      final data = chatDoc.data() as Map<String, dynamic>;
      final msgDoc = await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).get();
      
      if (msgDoc.exists) {
        final msgData = msgDoc.data() as Map<String, dynamic>;
        final msgText = msgData['text'] ?? '';
        final isImage = msgData['imageUrl'] != null;
        final displayTxt = isImage ? "📷 Photo" : msgText;

        if (data['lastMessage'] == displayTxt) {
          await _firestore.collection('chats').doc(chatId).update({
            'lastMessage': 'Message unsent',
          });
        }
      }
    }

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  /// Updates live location for a user in a specific chat.
  Future<void> updateLiveLocation(String chatId, String userId, double lat, double lng, {double? heading, double? accuracy, double? speed}) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('live_locations')
        .doc(userId)
        .set({
      'lat': lat,
      'lng': lng,
      'heading': heading ?? 0.0,
      'accuracy': accuracy ?? 0.0,
      'speed': speed ?? 0.0,
      'lastUpdate': FieldValue.serverTimestamp(),
      'isSharing': true,
    }, SetOptions(merge: true));
  }

  /// Stop sharing live location.
  Future<void> stopLiveLocation(String chatId, String userId) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('live_locations')
        .doc(userId)
        .update({
      'isSharing': false,
    });
  }

  /// Stream of all active live locations for a chat.
  Stream<QuerySnapshot> getLiveLocationsStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('live_locations')
        .where('isSharing', isEqualTo: true)
        .snapshots();
  }

  /// Mark a user as currently monitoring the chat's live location.
  Future<void> setMonitoringStatus(String chatId, String userId, String name, bool active) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('monitoring')
        .doc(userId)
        .set({
      'name': name,
      'active': active,
      'lastUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Stream of people currently monitoring the chat.
  Stream<QuerySnapshot> getMonitoringStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('monitoring')
        .where('active', isEqualTo: true)
        .snapshots();
  }
}
