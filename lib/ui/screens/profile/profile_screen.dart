// dart:typed_data removed - unused
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/app_state.dart';
import '../../../services/auth_service.dart';
import '../../../models/user_model.dart';
import '../auth/login_screen.dart';
import '../chat/chat_room_screen.dart';
import '../../../services/chat_service.dart';
import '../../../services/alarm_service.dart';
import 'siren_settings_screen.dart';
import '../../../services/web_permission_service.dart' 
    if (dart.library.js_util) '../../../services/web_permission_service_web.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isUploadingImage = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  dynamic _emailChangeVerificationResult;
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _voiceWordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().currentUser;
    _nameController.text = user?.name ?? '';
    _phoneController.text = user?.phone ?? '';
    _voiceWordController.text = user?.voiceTriggerCode ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _voiceWordController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Select Image Source", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFFE91E8C)),
              title: Text("Camera", style: GoogleFonts.outfit(color: Colors.white70)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFE91E8C)),
              title: Text("Gallery", style: GoogleFonts.outfit(color: Colors.white70)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 75, maxWidth: 512);
    if (picked == null || !mounted) return;

    final appState = context.read<AppState>();
    setState(() => _isUploadingImage = true);
    try {
      final bytes = await picked.readAsBytes();
      await appState.updateProfileImage(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Profile photo updated!"),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _saveProfile() async {
    final appState = context.read<AppState>();
    final user = appState.currentUser;
    if (user == null) return;

    appState.setLoading(true);
    await AuthService().updateProfile(
      user.uid,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      voiceTriggerCode: _voiceWordController.text.trim(),
    );
    await appState.fetchUser(user.uid);
    appState.setLoading(false);
    setState(() => _isEditing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Profile updated successfully!"),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;

    if (user == null) return const Center(child: Text("Not logged in."));

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        elevation: 0,
        title: Text("My Profile", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.white70),
        actions: [
          if (_isEditing)
            IconButton(icon: const Icon(Icons.check, color: Color(0xFFE91E8C)), onPressed: _saveProfile)
          else
            IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.white70), onPressed: () => setState(() => _isEditing = true)),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await AuthService().signOut();
              if (mounted) {
                navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
              }
            },
          ),
        ],
      ),
      body: appState.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E8C)))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Profile Avatar ──────────────────────────────────────
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 110, height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [Color(0xFFE91E8C), Color(0xFF9C27B0)]),
                          boxShadow: [BoxShadow(color: const Color(0xFFE91E8C).withValues(alpha: 0.35), blurRadius: 20, spreadRadius: 2)],
                        ),
                        child: GestureDetector(
                          onTap: () async {
                            if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
                              await launchUrl(Uri.parse(user.photoUrl!), mode: LaunchMode.externalApplication);
                            }
                          },
                          child: ClipOval(
                            child: _isUploadingImage
                                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                                : (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                                    ? Image.network(
                                        user.photoUrl!, 
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, stack) => Container(
                                          color: Colors.grey.shade800,
                                          child: const Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.broken_image, color: Colors.white30),
                                              Text("CORS", style: TextStyle(color: Colors.white30, fontSize: 8)),
                                            ],
                                          ),
                                        ),
                                      )
                                    : Icon(Icons.person_rounded, size: 60, color: Colors.white.withValues(alpha: 0.9)),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: GestureDetector(
                          onTap: _pickAndUploadImage,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE91E8C),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF0D0D1A), width: 2.5),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                Text(
                  user.email,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 13, color: Colors.white38),
                ),
                TextButton(
                  onPressed: _pickAndUploadImage,
                  child: Text("Change Profile Photo", style: GoogleFonts.outfit(color: const Color(0xFFE91E8C), fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 16),

                // ── Deterrent Controls (High Priority) ─────────────────────
                _sectionHeader("Emergency Deterrents"),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2A2A40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDeterrentOption(
                        "Audio Evidence", 
                        "Record 30s during SOS", 
                        Icons.mic_rounded, 
                        user.isAudioEnabled,
                        (val) => appState.updateAudioSetting(val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Editable Fields ──────────────────────────────────────
                _sectionHeader("Account Details"),
                const SizedBox(height: 12),
                _buildField("Full Name", _nameController, Icons.badge_outlined, _isEditing),
                _buildField("Phone", _phoneController, Icons.phone_outlined, _isEditing),
                _buildEmailSection(user),
                const SizedBox(height: 28),

                // ── Safety Settings ──────────────────────────────────────
                _sectionHeader("Safety Settings"),
                const SizedBox(height: 12),
                _buildSettingsCard(user, appState),
                const SizedBox(height: 28),

                // ── Emergency Contacts ───────────────────────────────────
                _sectionHeader("Emergency Contacts (Guardians)"),
                const SizedBox(height: 12),
                ...user.guardianPhones.map((phone) => _buildGuardianTile(phone, user, appState)).toList(),
                if (user.guardianPhones.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text("No emergency contacts yet.", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13)),
                  ),
                const SizedBox(height: 16),
                _addGuardianButton(appState),
                const SizedBox(height: 40),

                const Divider(color: Color(0xFF2A2A40)),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () => _showDeleteConfirmation(context, appState),
                  icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFE53935), size: 20),
                  label: Text(
                    "DELETE MY SENTINEL ACCOUNT",
                    style: GoogleFonts.outfit(color: const Color(0xFFE53935), fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1.2),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFFE53935).withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildDeterrentOption(String title, String subtitle, IconData icon, bool initialValue, Function(bool) onChanged) {
    bool val = initialValue;
    return StatefulBuilder(
      builder: (context, setState) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A40)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white38, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            Switch(
              value: val,
              activeColor: const Color(0xFFE91E8C),
              onChanged: (newVal) {
                setState(() => val = newVal);
                onChanged(newVal);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Delete Account?", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          "This will permanently delete your profile, guardian connections, and SOS history. This action cannot be undone.",
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            onPressed: () async {
              try {
                await appState.deleteAccount();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString()),
                    backgroundColor: const Color(0xFFE53935),
                  ));
                }
              }
            },
            child: const Text("DELETE PERMANENTLY", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(
    title,
    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white38, letterSpacing: 1.0),
  );

  Widget _buildSettingsCard(user, AppState appState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_callback_rounded, color: Color(0xFFE91E8C), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Fake Call Delay",
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E8C).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE91E8C).withValues(alpha: 0.4)),
                ),
                child: Text(
                  "${user.fakeCallDelay}s",
                  style: GoogleFonts.outfit(color: const Color(0xFFE91E8C), fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ),
          Text(
            "How long to wait before the fake call rings",
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFE91E8C),
              inactiveTrackColor: const Color(0xFF2A2A40),
              thumbColor: const Color(0xFFE91E8C),
              overlayColor: const Color(0xFFE91E8C).withValues(alpha: 0.2),
            ),
            child: Slider(
              value: user.fakeCallDelay.toDouble(),
              min: 3,
              max: 120,
              divisions: 39,
              label: "${user.fakeCallDelay} seconds",
              onChanged: (val) async {
                await appState.updateFakeCallDelay(val.toInt());
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("3s", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
              Text("120s", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF2A2A40)),
          const SizedBox(height: 16),
          
          // --- Fake Call Identity Section ---
          Row(
            children: [
              const Icon(Icons.person_pin_circle_rounded, color: Color(0xFFE91E8C), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Fake Caller Identity",
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Color(0xFFE91E8C), size: 18),
                onPressed: () => _showFakeCallIdentityDialog(user, appState),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A40)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("NAME", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text(user.fakeCallSenderName, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14)),
                  ],
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("NUMBER", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text(user.fakeCallSenderNumber, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // --- Voice Trigger & Accent Test ---
          Row(
            children: [
              const Icon(Icons.record_voice_over_rounded, color: Color(0xFFE91E8C), size: 20),
              const SizedBox(width: 10),
              Text(
                "Voice Trigger & Accent Test",
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A40)),
            ),
            child: Column(
              children: [
                Text(
                  "Say 'Sentinel' or 'বাঁচাও' in your natural accent to test the trigger.",
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                _VoiceTesterWidget(), // New interactive testing widget
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- Shake to SOS Toggle ---
          Row(
            children: [
              const Icon(Icons.vibration_rounded, color: Color(0xFFE91E8C), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Shake-to-SOS",
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      "Trigger SOS by shaking your phone 3 times",
                      style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: user.isShakeEnabled,
                activeColor: const Color(0xFFE91E8C),
                activeTrackColor: const Color(0xFFE91E8C).withValues(alpha: 0.3),
                onChanged: (val) async {
                  await appState.updateShakeSetting(val);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SirenSettingsScreen()));
            },
            icon: const Icon(Icons.lock_person_rounded, color: Colors.white70, size: 18),
            label: Text(
              user.sirenPassword1 == null ? "SET SIREN PASSWORDS" : "CHANGE SIREN PASSWORDS",
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          if (kIsWeb) 
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                       await WebPermissionService.requestMotionPermission();
                       if (mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Motion Permission Granted!")));
                       }
                    },
                    icon: const Icon(Icons.security_rounded, size: 16, color: Color(0xFFE91E8C)),
                    label: Text("Grant Browser Motion Access", style: GoogleFonts.outfit(color: const Color(0xFFE91E8C), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => WebPermissionService.forceAppUpdate(),
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white30),
                    label: Text("Force Update App", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF2A2A40)),
          const SizedBox(height: 12),
          
          const SizedBox(height: 12),
          
          // --- Platform Style Section ---
          Row(
            children: [
              const Icon(Icons.important_devices_rounded, color: Color(0xFFE91E8C), size: 20),
              const SizedBox(width: 10),
              Text(
                "Call UI Style",
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _styleOption(context, "iOS Style", "iOS", user.fakeCallPlatform, appState),
              const SizedBox(width: 10),
              _styleOption(context, "Android Style", "Android", user.fakeCallPlatform, appState),
            ],
          ),
          
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF2A2A40)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.record_voice_over_rounded, color: Color(0xFFE91E8C), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Voice Trigger Phrase",
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Speak this clearly to trigger SOS while the app is open",
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showVoiceTriggerDialog(user, appState),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A40)),
              ),
              child: Row(
                children: [
                  Text(
                    user.voiceTriggerCode.toUpperCase(),
                    style: GoogleFonts.outfit(color: const Color(0xFFE91E8C), fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                  ),
                  const Spacer(),
                  const Icon(Icons.edit_rounded, color: Colors.white24, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVoiceTriggerDialog(user, appState) {
    final ctrl = TextEditingController(text: user.voiceTriggerCode);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Set Voice Trigger", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Action Phrase",
                labelStyle: TextStyle(color: Colors.white54),
                hintText: "e.g. help sentinel",
                hintStyle: TextStyle(color: Colors.white24),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Keep it short (2-3 words) and distinct for better accuracy.",
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E8C), foregroundColor: Colors.white),
            onPressed: () async {
              final code = ctrl.text.trim().toLowerCase();
              if (code.isNotEmpty) {
                await appState.updateVoiceTriggerCode(code);
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _styleOption(BuildContext context, String label, String value, String current, AppState appState) {
    final selected = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => appState.updateFakeCallProfile(platform: value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE91E8C).withValues(alpha: 0.15) : const Color(0xFF0D0D1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? const Color(0xFFE91E8C) : const Color(0xFF2A2A40), width: selected ? 2 : 1),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: selected ? const Color(0xFFE91E8C) : Colors.white54,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  void _showFakeCallIdentityDialog(user, appState) {
    final nameCtrl = TextEditingController(text: user.fakeCallSenderName);
    final phoneCtrl = TextEditingController(text: user.fakeCallSenderNumber);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Fake Caller Details", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Caller Name", labelStyle: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Phone Number", labelStyle: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E8C), foregroundColor: Colors.white),
            onPressed: () async {
              await appState.updateFakeCallProfile(
                name: nameCtrl.text.trim(),
                number: phoneCtrl.text.trim(),
              );
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailSection(UserModel user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.email_outlined, color: Colors.white38, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Email Address", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
                Text(user.email, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showEmailChangeDialog(user),
            child: Text("Change", style: GoogleFonts.outfit(color: const Color(0xFFE91E8C), fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showEmailChangeDialog(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
            decoration: const BoxDecoration(
              color: Color(0xFF0D0D1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("Recover/Change Email", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  _emailChangeVerificationResult == null
                      ? "To change your email, verify your identity via security code sent to your phone."
                      : "Enter the security code and your new email address.",
                  style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
                ),
                const SizedBox(height: 32),
                if (_emailChangeVerificationResult == null) ...[
                  _isSendingOtp
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E8C)))
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE91E8C),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            setModalState(() => _isSendingOtp = true);
                            try {
                              await AuthService().sendEmailOtp(user.email);
                              setModalState(() {
                                _emailChangeVerificationResult = "sent";
                                _isSendingOtp = false;
                              });
                            } catch (err) {
                              setModalState(() => _isSendingOtp = false);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
                            }
                          },
                          child: Text("SEND SECURITY CODE", style: GoogleFonts.outfit(fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                        ),
                ] else ...[
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.white, letterSpacing: 6),
                    textAlign: TextAlign.center,
                    decoration: _inputDecoration("6-Digit Code", Icons.security_rounded).copyWith(counterText: ""),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _newEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("New Email Address", Icons.alternate_email_rounded),
                  ),
                  const SizedBox(height: 32),
                  _isVerifyingOtp
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            setModalState(() => _isVerifyingOtp = true);
                            try {
                              await AuthService().verifyEmailOtp(user.email, _otpController.text.trim());
                              await AuthService().updateAccountEmail(_newEmailController.text.trim());
                              if (mounted) {
                                Navigator.pop(ctx);
                                final uid = context.read<AppState>().currentUser?.uid;
                                if (uid != null) context.read<AppState>().fetchUser(uid);
                                _showSuccess("Email updated! Check your new inbox to confirm.");
                              }
                            } catch (e) {
                              setModalState(() => _isVerifyingOtp = false);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                            }
                          },
                          child: Text("VERIFY & UPDATE EMAIL", style: GoogleFonts.outfit(fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                        ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      setState(() {
        _emailChangeVerificationResult = null;
        _otpController.clear();
        _newEmailController.clear();
      });
    });
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF4CAF50),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.white38),
      filled: true,
      fillColor: const Color(0xFF1A1A2E),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF2A2A40), width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE91E8C), width: 2)),
    );
  }

  Widget _buildGuardianTile(String phone, user, AppState appState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A40)),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0x22E91E8C),
          child: Icon(Icons.contact_phone_rounded, color: Color(0xFFE91E8C), size: 20),
        ),
        title: Text(phone, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500)),
        subtitle: Text("Emergency Guardian", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF7B61FF), size: 20),
              onPressed: () async {
                final chatService = ChatService();
                final guardianUid = await chatService.getUserByPhone(phone);
                if (guardianUid != null && mounted) {
                  final chatId = chatService.getChatRoomId(user.uid, guardianUid);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ChatRoomScreen(chatId: chatId, currentUserId: user.uid, otherName: "Guardian ($phone)"),
                  ));
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Guardian isn't on Sentinel yet.")));
                }
              },
            ),
            if (_isEditing)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFE53935), size: 20),
                onPressed: () => appState.removeGuardian(phone),
              ),
          ],
        ),
      ),
    );
  }

  Widget _addGuardianButton(AppState appState) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE91E8C).withValues(alpha: 0.5)),
      ),
      child: TextButton.icon(
        onPressed: () {
          final ctrl = TextEditingController();
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("Add Guardian", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
              content: TextField(
                controller: ctrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Phone Number",
                  labelStyle: TextStyle(color: Colors.white54),
                  hintText: "01XXXXXXXXX",
                  hintStyle: TextStyle(color: Colors.white24),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.white38))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E8C), foregroundColor: Colors.white),
                  onPressed: () {
                    final phone = ctrl.text.trim();
                    if (phone.isNotEmpty) { 
                      final normalized = AuthService.normalizePhone(phone);
                      appState.addGuardian(normalized); 
                      Navigator.pop(ctx); 
                    }
                  },
                  child: const Text("Add"),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.add_rounded, color: Color(0xFFE91E8C)),
        label: Text("Add Emergency Contact", style: GoogleFonts.outfit(color: const Color(0xFFE91E8C), fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A40)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
              Text(value.isNotEmpty ? value : "Not set", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, bool enabled) {
    if (!enabled) return _buildInfoTile(label, controller.text, icon);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: Colors.white38),
          filled: true,
          fillColor: const Color(0xFF1A1A2E),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF2A2A40))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE91E8C), width: 2)),
        ),
      ),
    );
  }
}

class _VoiceTesterWidget extends StatefulWidget {
  @override
  __VoiceTesterWidgetState createState() => __VoiceTesterWidgetState();
}

class __VoiceTesterWidgetState extends State<_VoiceTesterWidget> {
  final SpeechToText _speech = SpeechToText();
  String _lastWords = "Tap mic and say 'Sentinel'";
  bool _isListening = false;

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _lastWords = val.recognizedWords;
            String lower = _lastWords.toLowerCase();
            // Match against multi-language triggers
            if (lower.contains("sentinel") || lower.contains("সেন্টিনেল") || lower.contains("বাঁচাও")) {
              _lastWords = "🚨 TRIGGERED: $_lastWords";
            }
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _lastWords,
            style: GoogleFonts.outfit(
              color: _lastWords.startsWith("🚨") ? const Color(0xFFFF5252) : Colors.white,
              fontSize: 15,
              fontWeight: _lastWords.startsWith("🚨") ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _listen,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isListening ? const Color(0xFFE91E8C) : const Color(0xFF2A2A40),
              boxShadow: _isListening ? [
                BoxShadow(color: const Color(0xFFE91E8C).withValues(alpha: 0.4), blurRadius: 15, spreadRadius: 2)
              ] : [],
            ),
            child: Icon(
              _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }
}

