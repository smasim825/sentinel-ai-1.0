import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';

class AppState extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  Future<void> fetchUser(String uid) async {
    _isLoading = true;
    notifyListeners();
    _currentUser = await _authService.getUserData(uid);
    _isLoading = false;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> addGuardian(String phone) async {
    if (_currentUser == null) return;
    setLoading(true);
    try {
      await _authService.addGuardian(_currentUser!.uid, phone);
      
      // Also initialize chat so it appears in the list instantly
      final chatService = ChatService();
      final guardianUid = await chatService.getUserByPhone(phone);
      if (guardianUid != null) {
        final chatId = chatService.getChatRoomId(_currentUser!.uid, guardianUid);
        await chatService.initializeChat(chatId, _currentUser!.uid, guardianUid, isMonitoring: true);
      }
      
      await fetchUser(_currentUser!.uid);
    } catch (e) {
      debugPrint("Error adding guardian: $e");
    } finally {
      setLoading(false);
    }
  }

  Future<void> removeGuardian(String phone) async {
    if (_currentUser == null) return;
    setLoading(true);
    try {
      // 1. Remove from guardian list
      await _authService.removeGuardian(_currentUser!.uid, phone);
      
      // 2. Deactivate the chat monitoring status
      final chatService = ChatService();
      final guardianUid = await chatService.getUserByPhone(phone);
      if (guardianUid != null) {
        final chatId = chatService.getChatRoomId(_currentUser!.uid, guardianUid);
        await chatService.setChatMonitoringActive(chatId, false);
      }
      
      await fetchUser(_currentUser!.uid);
    } catch (e) {
      debugPrint("Error removing guardian: $e");
    } finally {
      setLoading(false);
    }
  }

  Future<void> removeMeAsGuardian(String targetUid) async {
    if (_currentUser == null) return;
    setLoading(true);
    try {
      // 1. Try to remove phone from their record (may fail due to permissions)
      await _authService.removeMeAsGuardian(targetUid, _currentUser!.phone);
      
      // 2. Also deactivate monitoring in the chat document (user has permission here)
      final chatService = ChatService();
      final chatId = chatService.getChatRoomId(_currentUser!.uid, targetUid);
      await chatService.setChatMonitoringActive(chatId, false);
    } catch (e) {
      debugPrint("Error in removeMeAsGuardian: $e");
    } finally {
      setLoading(false);
    }
  }

  Future<String?> updateProfileImage(Uint8List imageBytes) async {
    if (_currentUser == null) return null;
    setLoading(true);
    try {
      final url = await _authService.uploadProfileImage(_currentUser!.uid, imageBytes);
      await fetchUser(_currentUser!.uid);
      return url;
    } finally {
      setLoading(false);
    }
  }

  Future<void> updateFakeCallDelay(int seconds) async {
    if (_currentUser == null) return;
    await _authService.updateSafetySettings(_currentUser!.uid, fakeCallDelay: seconds);
    await fetchUser(_currentUser!.uid);
  }

  Future<void> updateFakeCallProfile({String? name, String? number, String? platform}) async {
    if (_currentUser == null) return;
    await _authService.updateSafetySettings(
      _currentUser!.uid,
      fakeCallSenderName: name,
      fakeCallSenderNumber: number,
      fakeCallPlatform: platform,
    );
    await fetchUser(_currentUser!.uid);
  }

  Future<void> updateVoiceTriggerCode(String code) async {
    if (_currentUser == null) return;
    await _authService.updateSafetySettings(_currentUser!.uid, voiceTriggerCode: code);
    await fetchUser(_currentUser!.uid);
    notifyListeners();
  }

  Future<void> updateShakeSetting(bool enabled) async {
    if (_currentUser == null) return;
    await _authService.updateSafetySettings(_currentUser!.uid, isShakeEnabled: enabled);
    await fetchUser(_currentUser!.uid);
  }

  Future<void> updateSirenSetting(bool enabled) async {
    if (_currentUser == null) return;
    await _authService.updateSafetySettings(_currentUser!.uid, isSirenEnabled: enabled);
    await fetchUser(_currentUser!.uid);
  }

  Future<void> updateSirenPasswords(String pass1, String pass2) async {
    if (_currentUser == null) return;
    final h1 = _hashPassword(pass1);
    final h2 = _hashPassword(pass2);
    await _authService.updateSafetySettings(_currentUser!.uid, sirenPassword1: h1, sirenPassword2: h2);
    await fetchUser(_currentUser!.uid);
  }

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  bool verifySirenPassword1(String input) {
    if (_currentUser?.sirenPassword1 == null) return false;
    return _hashPassword(input) == _currentUser!.sirenPassword1;
  }

  bool verifySirenPassword2(String input) {
    if (_currentUser?.sirenPassword2 == null) return false;
    return _hashPassword(input) == _currentUser!.sirenPassword2;
  }

  Future<void> updateStrobeSetting(bool enabled) async {
    if (_currentUser == null) return;
    await _authService.updateSafetySettings(_currentUser!.uid, isStrobeEnabled: enabled);
    await fetchUser(_currentUser!.uid);
  }

  Future<void> updateAudioSetting(bool enabled) async {
    if (_currentUser == null) return;
    await _authService.updateSafetySettings(_currentUser!.uid, isAudioEnabled: enabled);
    await fetchUser(_currentUser!.uid);
  }

  Future<void> deleteAccount() async {
    await _authService.deleteAccount();
    _currentUser = null;
    notifyListeners();
  }
}
