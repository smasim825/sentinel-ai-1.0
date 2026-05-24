import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'email_otp_service.dart';
import 'phone_otp_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EmailOtpService _otpService = EmailOtpService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  static String normalizePhone(String phone) {
    // 1. Remove all non-numeric characters except +
    String cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    
    // 2. Handle double country code issue (e.g., +880017...)
    if (cleaned.startsWith('+8800')) {
      cleaned = '+880' + cleaned.substring(5);
    }
    
    // 3. If it starts with +, return cleaned version
    if (cleaned.startsWith('+')) {
      return cleaned;
    }

    // 4. Handle local BD numbers starting with 01
    if (cleaned.length == 11 && cleaned.startsWith('01')) {
      return '+88' + cleaned;
    }
    
    // 5. Default fallback
    return '+' + cleaned.replaceAll('+', '');
  }

  /// Fetches current user data if logged in
  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await getUserData(user.uid);
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
    return null;
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      User? user = result.user;
      if (user != null) {
        // Fast local storage of UID
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('uid', user.uid);
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw "Login error: ${e.toString()}";
    }
  }

  // STEP 1: Send OTP before creating account
  Future<void> sendPreRegistrationOtp(String email, String name) async {
    // We do not query the database here to protect user privacy and avoid permission errors.
    // Firebase Auth will automatically reject the signup at Step 2 if the email is already taken.
    await _otpService.sendOtp(email.toLowerCase().trim(), name: name.trim());
  }

  // STEP 2: Verify OTP and create the account
  Future<User?> completeRegistration(
    String name,
    String email,
    String phone,
    String password,
    String otpCode, {
    Uint8List? photoBytes,
  }) async {
    try {
      // 1. Verify OTP First! (Throws exception if wrong)
      await _otpService.verifyOtp(email.trim(), otpCode, persist: false);

      // 2. Create Auth account only after verification
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        String? photoUrl;
        if (photoBytes != null) {
          final ref = FirebaseStorage.instance.ref().child('profile_images/${user.uid}.jpg');
          await ref.putData(photoBytes, SettableMetadata(contentType: 'image/jpeg'));
          photoUrl = await ref.getDownloadURL();
        }

        // 3. Save user data (Now marked as verified instantly)
        final userData = {
          'uid': user.uid,
          'name': name.trim(),
          'email': email.toLowerCase().trim(),
          'phone': normalizePhone(phone),
          'photoUrl': photoUrl,
          'guardianPhones': [],
          'isSosActive': false,
          'isEmailVerified': true, // Auto-verified!
          'isPhoneVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
          'isShakeEnabled': true,
        };

        await _firestore.collection('users').doc(user.uid).set(userData);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('uid', user.uid);
        
        return user;
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      String msg = e.toString();
      if (msg.contains("Exception: ")) msg = msg.split("Exception: ").last;
      throw "Registration failed: $msg";
    }
    return null;
  }

  Future<void> sendEmailOtp(String email) async {
    try {
      // We do not query the database here to protect user privacy and avoid permission errors for logged-out users.
      // If the email doesn't exist, the final password reset step will fail securely.
      await _otpService.sendOtp(email.toLowerCase().trim(), name: 'User');
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        throw "Access Denied: Please update your Firestore rules to allow OTP requests.";
      }
      rethrow;
    }
  }

  Future<void> verifyEmailOtp(String email, String code, {bool persist = false}) async {
    await _otpService.verifyOtp(email, code, persist: persist);
    
    // Mark as verified if logged in
    if (_auth.currentUser != null && _auth.currentUser!.email?.toLowerCase() == email.toLowerCase()) {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({'isEmailVerified': true});
    }
  }

  Future<void> resetPasswordWithOtp(String email, String code, String newPassword) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('forceResetPassword');
      await callable.call({
        'email': email.toLowerCase().trim(),
        'otp': code.trim(),
        'newPassword': newPassword.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? "Failed to reset password via server.";
    } catch (e) {
      // Fallback for non-Firebase errors
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('uid');
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // 1. Remove user from all their active chats (hides chats from them, keeps for other person)
      final userChats = await _firestore.collection('chats').where('participants', arrayContains: user.uid).get();
      for (var chat in userChats.docs) {
        await chat.reference.update({
          'participants': FieldValue.arrayRemove([user.uid])
        });
      }

      // 2. Delete Firestore User Doc
      await _firestore.collection('users').doc(user.uid).delete();

      // 3. Delete Profile Image if exists
      try {
        await FirebaseStorage.instance.ref().child('profile_images/${user.uid}.jpg').delete();
      } catch (_) {}

      // 4. Delete Auth User
      await user.delete();
      
      // 5. Clear Local Prefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('uid');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw "Security Error: Please log out and log back in before deleting your account.";
      }
      rethrow;
    } catch (e) {
      throw "Error deleting account: ${e.toString()}";
    }
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password': return "Password is too weak. Please use a stronger one.";
      case 'email-already-in-use': return "An account already exists with this email.";
      case 'user-not-found': return "Account not found. Please check your email.";
      case 'wrong-password': return "Incorrect password. Please try again.";
      case 'invalid-credential': return "Wrong email or password. Please try again.";
      case 'invalid-email': return "Please enter a valid email address.";
      default: return "Login failed. Please check your details and try again.";
    }
  }
  
  // Method to remove a guardian from the CURRENT user's list
  Future<void> removeGuardian(String uid, String phone) async {
    final normalized = normalizePhone(phone);
    await _firestore.collection('users').doc(uid).update({
      'guardianPhones': FieldValue.arrayRemove([normalized])
    });
  }

  Future<void> addGuardian(String uid, String phone) async {
    final normalized = normalizePhone(phone);
    await _firestore.collection('users').doc(uid).update({
      'guardianPhones': FieldValue.arrayUnion([normalized])
    });
  }

  Future<String?> uploadProfileImage(String uid, Uint8List bytes) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('profile_images/$uid.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await _firestore.collection('users').doc(uid).update({'photoUrl': url});
      return url;
    } catch (e) {
      debugPrint("Error uploading image: $e");
      return null;
    }
  }

  Future<void> updateProfile(String uid, {String? name, String? phone, String? photoUrl, String? voiceTriggerCode}) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = normalizePhone(phone);
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    if (voiceTriggerCode != null) data['voiceTriggerCode'] = voiceTriggerCode;
    
    if (data.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update(data);
    }
  }

  Future<void> updateSafetySettings(
    String uid, {
    int? fakeCallDelay,
    String? fakeCallSenderName,
    String? fakeCallSenderNumber,
    String? fakeCallPlatform,
    String? voiceTriggerCode,
    bool? isShakeEnabled,
    bool? isSirenEnabled,
    bool? isStrobeEnabled,
    bool? isAudioEnabled,
    String? sirenPassword1,
    String? sirenPassword2,
  }) async {
    final data = <String, dynamic>{};
    if (fakeCallDelay != null) data['fakeCallDelay'] = fakeCallDelay;
    if (fakeCallSenderName != null) data['fakeCallSenderName'] = fakeCallSenderName;
    if (fakeCallSenderNumber != null) data['fakeCallSenderNumber'] = fakeCallSenderNumber;
    if (fakeCallPlatform != null) data['fakeCallPlatform'] = fakeCallPlatform;
    if (voiceTriggerCode != null) data['voiceTriggerCode'] = voiceTriggerCode;
    if (isShakeEnabled != null) data['isShakeEnabled'] = isShakeEnabled;
    if (isSirenEnabled != null) data['isSirenEnabled'] = isSirenEnabled;
    if (isStrobeEnabled != null) data['isStrobeEnabled'] = isStrobeEnabled;
    if (isAudioEnabled != null) data['isAudioEnabled'] = isAudioEnabled;
    if (sirenPassword1 != null) data['sirenPassword1'] = sirenPassword1;
    if (sirenPassword2 != null) data['sirenPassword2'] = sirenPassword2;

    if (data.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update(data);
    }
  }

  Future<void> updateAccountEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.verifyBeforeUpdateEmail(newEmail.trim());
      await _firestore.collection('users').doc(user.uid).update({'email': newEmail.toLowerCase().trim()});
    } else {
      throw "User not logged in.";
    }
  }

  // Method to remove the CURRENT user from another person's guardian list
  Future<void> removeMeAsGuardian(String targetUid, String myPhone) async {
    try {
      final normalized = normalizePhone(myPhone);
      await _firestore.collection('users').doc(targetUid).update({
        'guardianPhones': FieldValue.arrayRemove([normalized])
      });
    } catch (e) {
      debugPrint("Error removing self as guardian: $e");
    }
  }
}
