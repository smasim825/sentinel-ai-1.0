class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final List<String> guardianPhones;
  final bool isSosActive;
  final String role;
  final String? photoUrl;
  final int fakeCallDelay; // seconds
  final String voiceTriggerCode;
  final String fakeCallSenderName;
  final String fakeCallSenderNumber;
  final String fakeCallPlatform; // "iOS" or "Android"
  final bool isEmailVerified;
  final bool isShakeEnabled;
  final bool isSirenEnabled;
  final bool isStrobeEnabled;
  final bool isAudioEnabled;
  final String? sirenPassword1; // hashed
  final String? sirenPassword2; // hashed

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.guardianPhones,
    required this.role,
    this.photoUrl,
    this.isSosActive = false,
    this.fakeCallDelay = 5,
    this.voiceTriggerCode = "help sentinel",
    this.fakeCallSenderName = "Dad",
    this.fakeCallSenderNumber = "01712345678",
    this.fakeCallPlatform = "iOS",
    this.isEmailVerified = false,
    this.isShakeEnabled = true,
    this.isSirenEnabled = true,
    this.isStrobeEnabled = true,
    this.isAudioEnabled = true,
    this.sirenPassword1,
    this.sirenPassword2,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      guardianPhones: List<String>.from(data['guardianPhones'] ?? []),
      isSosActive: data['isSosActive'] ?? false,
      role: data['role'] ?? 'User',
      photoUrl: data['photoUrl'],
      fakeCallDelay: (data['fakeCallDelay'] as num?)?.toInt() ?? 5,
      voiceTriggerCode: data['voiceTriggerCode'] ?? "help sentinel",
      fakeCallSenderName: data['fakeCallSenderName'] ?? "Dad",
      fakeCallSenderNumber: data['fakeCallSenderNumber'] ?? "01712345678",
      fakeCallPlatform: data['fakeCallPlatform'] ?? "iOS",
      isEmailVerified: data['isEmailVerified'] ?? false,
      isShakeEnabled: data['isShakeEnabled'] ?? true,
      isSirenEnabled: data['isSirenEnabled'] ?? true,
      isStrobeEnabled: data['isStrobeEnabled'] ?? true,
      isAudioEnabled: data['isAudioEnabled'] ?? true,
      sirenPassword1: data['sirenPassword1'],
      sirenPassword2: data['sirenPassword2'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'guardianPhones': guardianPhones,
      'isSosActive': isSosActive,
      'role': role,
      'photoUrl': photoUrl,
      'fakeCallDelay': fakeCallDelay,
      'voiceTriggerCode': voiceTriggerCode,
      'fakeCallSenderName': fakeCallSenderName,
      'fakeCallSenderNumber': fakeCallSenderNumber,
      'fakeCallPlatform': fakeCallPlatform,
      'isEmailVerified': isEmailVerified,
      'isShakeEnabled': isShakeEnabled,
      'isSirenEnabled': isSirenEnabled,
      'isStrobeEnabled': isStrobeEnabled,
      'isAudioEnabled': isAudioEnabled,
      'sirenPassword1': sirenPassword1,
      'sirenPassword2': sirenPassword2,
    };
  }
}
