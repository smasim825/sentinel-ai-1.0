import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math' show sqrt;
import '../../../providers/app_state.dart';
import '../../../models/user_model.dart';
import '../../../services/sos_service.dart';
import '../../../services/background_sync_service.dart';
import '../../../services/audio_record_service.dart';
import '../../../services/camera_service.dart';
import 'package:camera/camera.dart';
import '../../../services/chat_service.dart';
import '../../../services/alarm_service.dart';
import '../../../services/voice_trigger_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/shortcut_service.dart';
import '../../../services/native_emergency_service.dart';
import '../fake_call/inbound_call_overlay.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../profile/profile_screen.dart';
import '../emergency/siren_active_screen.dart';
import '../../widgets/sos_button.dart';
import '../biometric/biometric_dashboard_screen.dart';
import '../info/safety_guide_screen.dart';
// Conditional import: Use the web version on web, and the safe stub on mobile.
import '../../../services/web_permission_service.dart' 
    if (dart.library.js_util) '../../../services/web_permission_service_web.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SosService _sosService = SosService();
  final AudioRecordService _audioService = AudioRecordService();
  final ChatService _chatService = ChatService();
  final AlarmService _alarmService = AlarmService();
  final VoiceTriggerService _voiceService = VoiceTriggerService();
  final Battery _battery = Battery();
  
  bool _sosActive = false;
  StreamSubscription? _shakeSubscription;

  // Shake detection state (mirrors React useShakeDetection hook)
  double _lastMagnitude = 0.0;        // tracks last magnitude for delta calc
  int _lastShakeTimeMs = 0;           // debounce: ms timestamp of last counted shake
  final List<int> _shakeTimestamps = []; // sliding window of shake timestamps

  StreamSubscription<Position>? _positionStream;

  // SOS Countdown State
  bool _isCountdownActive = false;
  int _remainingSeconds = 5;
  Timer? _countdownTimer;

  // Fake Call State
  bool _isFakeCallCountdownActive = false;
  int _fakeCallRemainingSeconds = 5;
  Timer? _fakeCallTimer;

  bool _webShakeEnabled = false;

  @override
  void initState() {
    super.initState();
    _initShake();
    _initVoice();
    _initBackgroundNotification();
    _checkGuardianStatus();
    _checkExistingSos();
    if (!kIsWeb) {
      ShortcutService().init(context);
      // 📱 Request SMS & Call permissions proactively for offline SOS
      NativeEmergencyService().requestSmsPermission();
      NativeEmergencyService().requestCallPermission();
    }
  }

  void _checkExistingSos() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AppState>().currentUser;
      if (user != null && user.isSosActive) {
        setState(() => _sosActive = true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-init sensors when settings might have changed in AppState
    _initShake();
    _initVoice();
  }

  void _initBackgroundNotification() {
    if (!kIsWeb) {
      NotificationService().showStickySosNotification();
    }
  }

  void _initVoice() async {
    final user = context.read<AppState>().currentUser;
    if (user == null) return;
    
    // Initialize the service with the SOS callback
    bool available = await _voiceService.init(() {
      if (!_sosActive && !_isCountdownActive) {
        _handleSosPress();
      }
    });
    
    if (available) {
      // Start listening with the user's custom codeword (if any)
      _voiceService.startListening(customCode: user.voiceTriggerCode);
    }
  }

  // Exact Flutter port of the React useShakeDetection hook:
  // - Uses magnitude DELTA (change between readings), not raw magnitude
  // - 300ms debounce between counted shakes
  // - Sliding 2-second window: keeps timestamps of recent shakes, drops stale ones
  // - Fires when 3 timestamps exist inside the window
  void _initShake() {
    final user = context.read<AppState>().currentUser;
    if (user == null || !user.isShakeEnabled) {
      _shakeSubscription?.cancel();
      _shakeSubscription = null;
      // Reset all state (mirrors cleanup in useEffect return)
      _lastMagnitude = 0.0;
      _lastShakeTimeMs = 0;
      _shakeTimestamps.clear();
      return;
    }

    const double threshold   = 15.0; // delta m/s² to count as a shake
    const int    debounceMs  = 300;  // min ms between counted shakes
    const int    windowMs    = 3000; // sliding window duration in ms (updated to 3s)
    const int    shakesNeeded = 3;   // shakes required within the window

    _shakeSubscription?.cancel();
    _shakeSubscription = accelerometerEvents.listen((event) {
      // 1. Compute raw magnitude — mirrors Math.sqrt(x²+y²+z²) in React hook
      final double mag = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      // 2. Delta from last reading — mirrors `delta = |magnitude - lastMagnitudeRef.current|`
      final double delta = (mag - _lastMagnitude).abs();
      _lastMagnitude = mag;

      if (delta < threshold) return;

      // 3. Debounce: ignore if too soon after last counted shake (mirrors debounceMs check)
      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - _lastShakeTimeMs < debounceMs) return;
      _lastShakeTimeMs = nowMs;

      // 4. Sliding window: keep only timestamps within windowMs (mirrors shakesRef.current.filter)
      _shakeTimestamps.removeWhere((t) => nowMs - t >= windowMs);
      _shakeTimestamps.add(nowMs);

      debugPrint('📳 Shake delta: ${delta.toStringAsFixed(1)} — window count: ${_shakeTimestamps.length}/$shakesNeeded');

      // 5. Trigger SOS if enough shakes in window (mirrors shakesRef.current.length >= shakesRequired)
      if (_shakeTimestamps.length >= shakesNeeded) {
        _shakeTimestamps.clear(); // reset immediately so it doesn't fire again
        if (!_sosActive && !_isCountdownActive) {
          debugPrint('📳 3-shake SOS triggered!');
          _handleSosPress();
        }
      }
    });
  }

  void _checkGuardianStatus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AppState>().currentUser;
      if (user != null && user.guardianPhones.isEmpty) {
        _showGuardianReminder();
      }
    });
  }

  void _showGuardianReminder() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFE91E8C)),
            const SizedBox(width: 10),
            Text("Setup Guardian", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "You haven't connected a guardian yet. Sentinel cannot alert anyone without a saved emergency contact.",
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("LATER", style: GoogleFonts.outfit(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E8C)),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
            child: Text("CONNECT NOW", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Request motion permission for Web (iOS Safari specifically)
  Future<void> _requestWebMotionPermission() async {
    setState(() => _webShakeEnabled = true);
    
    // Call our safe service (works on Web, does nothing on Android)
    await WebPermissionService.requestMotionPermission();

    _initShake();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("📳 Shake-to-SOS is now active! Try shaking your phone."),
        backgroundColor: Color(0xFFE91E8C),
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _shakeSubscription?.cancel();
    // Reset shake state on dispose (mirrors useEffect cleanup)
    _lastMagnitude = 0.0;
    _lastShakeTimeMs = 0;
    _shakeTimestamps.clear();
    _positionStream?.cancel();
    super.dispose();
  }

  void _handleSosPress() {
    if (_sosActive || _isCountdownActive) return;

    setState(() {
      _isCountdownActive = true;
      _remainingSeconds = 5;
    });

    // Provide initial vibration
    if (!kIsWeb) Vibration.vibrate(duration: 500);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });
        // Pulse vibration every second
        if (!kIsWeb) Vibration.vibrate(duration: 300);
      } else {
        _countdownTimer?.cancel();
        _activateSos();
      }
    });
  }

  void _cancelSosCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _isCountdownActive = false;
      _remainingSeconds = 5;
    });
    if (!kIsWeb) Vibration.cancel();
  }

  void _handleFakeCallPress() {
    if (_sosActive || _isCountdownActive || _isFakeCallCountdownActive) return;

    final user = context.read<AppState>().currentUser;
    setState(() {
      _isFakeCallCountdownActive = true;
      _fakeCallRemainingSeconds = user?.fakeCallDelay ?? 5;
    });

    _fakeCallTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_fakeCallRemainingSeconds > 1) {
        setState(() => _fakeCallRemainingSeconds--);
      } else {
        _fakeCallTimer?.cancel();
        _launchFakeCall();
      }
    });
  }

  void _cancelFakeCall() {
    _fakeCallTimer?.cancel();
    setState(() {
      _isFakeCallCountdownActive = false;
    });
  }

  void _handleManualSirenPress({bool isFromSos = false}) {
    _alarmService.playSiren(useStrobe: context.read<AppState>().currentUser?.isStrobeEnabled ?? true);
    _voiceService.stopListening();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SirenActiveScreen(isFromSos: isFromSos)),
    ).then((_) {
      // Re-enable voice trigger when returning from siren screen
      final currentUser = context.read<AppState>().currentUser;
      if (currentUser != null && !_sosActive) {
        _voiceService.startListening(customCode: currentUser.voiceTriggerCode);
      }
    });
  }

  void _launchFakeCall() {
    final user = context.read<AppState>().currentUser;
    if (user == null) return;

    setState(() => _isFakeCallCountdownActive = false);

    // Stop voice trigger to release microphone during fake call
    _voiceService.stopListening();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InboundCallOverlay(
          name: user.fakeCallSenderName,
          number: user.fakeCallSenderNumber,
          isIos: user.fakeCallPlatform == "iOS",
        ),
      ),
    ).then((_) {
      // Re-enable voice trigger when returning from fake call
      final currentUser = context.read<AppState>().currentUser;
      if (currentUser != null && !_sosActive) {
        _voiceService.startListening(customCode: currentUser.voiceTriggerCode);
      }
    });
  }

  void _activateSos() async {
    final appState = context.read<AppState>();
    final user = appState.currentUser;
    if (user == null) return;

    setState(() {
      _sosActive = true;
      _isCountdownActive = false;
    });
    
    final guardians = user.guardianPhones;

    // 🛡️ SAFARI FIX: Initialize mic permission immediately on tap to keep User Gesture context
    if (user.isAudioEnabled) {
      await _audioService.hasPermission();
    }
    
    _voiceService.stopListening();

    final startTime = DateTime.now();

    // 1. Send SMS + In-App Chat alerts + Twilio Calls to guardians
    await _sosService.triggerSos(user.uid, user.name, guardians);

    // 2. Start Real-time Foreground Location Tracking Loop
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen((position) async {
      int level = 0;
      try { level = await _battery.batteryLevel; } catch (_) {}
      // Sync to global location document
      await _sosService.syncLocationToCloud(user.uid, position, level);
      // Sync to individual guardian chats for interactive mapping with heading/accuracy
      await _sosService.updateSosLiveLocation(user.uid, guardians, position);
    });

    // 3. Start 15-minute background location tracking (for long-term backup)
    await BackgroundSyncService.startTracking();

    // 4. Record audio evidence if enabled (First 30 seconds of quiet evidence collection)
    String? audioUrl;
    if (user.isAudioEnabled) {
      audioUrl = await _audioService.recordAndUpload(uid: user.uid, durationSeconds: 30);
    }
    
    // 5. Take Silent Snapshots (Front & Back)
    final CameraService cameraService = CameraService();
    final frontPhoto = await cameraService.takeSnapshot(direction: CameraLensDirection.front, uid: user.uid);
    final backPhoto = await cameraService.takeSnapshot(direction: CameraLensDirection.back, uid: user.uid);

    final globalChatId = "global_sos_${user.uid}";

    if (audioUrl != null) {
      final String msg = "🔴 SOS TRIGGERED — Audio Evidence:\n$audioUrl";
      await _chatService.sendMessage(globalChatId, user.uid, msg);
      for (String phone in guardians) {
        final gUid = await _chatService.getUserByPhone(phone);
        if (gUid != null) {
          final chatId = _chatService.getChatRoomId(user.uid, gUid);
          await _chatService.sendMessage(chatId, user.uid, msg);
        }
      }
    }

    // Send Photo Evidence
    if (frontPhoto != null || backPhoto != null) {
      for (String phone in guardians) {
        final guardianUid = await _chatService.getUserByPhone(phone);
        if (guardianUid != null) {
          final chatId = _chatService.getChatRoomId(user.uid, guardianUid);
          if (frontPhoto != null) await _chatService.sendMessage(chatId, user.uid, "📸 SOS TRIGGERED — Front Snapshot", imageUrl: frontPhoto);
          if (backPhoto != null) await _chatService.sendMessage(chatId, user.uid, "📸 SOS TRIGGERED — Back Snapshot", imageUrl: backPhoto);
        }
      }
      // Also send to global dispatch
      if (frontPhoto != null) await _chatService.sendMessage(globalChatId, user.uid, "📸 SOS TRIGGERED — Front Snapshot", imageUrl: frontPhoto);
      if (backPhoto != null) await _chatService.sendMessage(globalChatId, user.uid, "📸 SOS TRIGGERED — Back Snapshot", imageUrl: backPhoto);
    }

    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text("📢 Audio and Photo evidence shared with guardians!")),
       );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🚨 SOS Activated! Location + Audio shared with guardians."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }

    // 6. Restart voice trigger in main isolate if SOS is active and manual siren is not running
    if (_sosActive && !_alarmService.isPlaying) {
      _voiceService.startListening(customCode: user.voiceTriggerCode);
    }
  }

  void _stopSos() async {
    final user = context.read<AppState>().currentUser;
    if (user != null) {
      await _sosService.stopSos(user.uid);
    }

    await _positionStream?.cancel();
    _positionStream = null;
    await BackgroundSyncService.stopTracking();
    await _alarmService.stopSiren();
    _voiceService.startListening(customCode: user?.voiceTriggerCode);
    
    if (mounted) {
      setState(() => _sosActive = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ You are safe. SOS tracking stopped."),
          backgroundColor: Colors.green,
        ),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0D1A),
          elevation: 0,
          title: Text("Sentinel Safety", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.white70),
              tooltip: 'Safety Guide',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyGuideScreen())),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                child: Hero(
                  tag: 'profile_pic',
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFFE91E8C), Color(0xFF9C27B0)]),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF1A1A2E),
                      backgroundImage: (user != null && user.photoUrl != null && user.photoUrl!.isNotEmpty) ? NetworkImage(user.photoUrl!) : null,
                      child: (user == null || user.photoUrl == null || user.photoUrl!.isEmpty) 
                        ? const Icon(Icons.person, size: 24, color: Colors.white70) 
                        : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: const Color(0xFF0D0D1A),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF0D0D1A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                accountName: Text(user?.name ?? "User", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                accountEmail: Text(user?.email ?? "", style: GoogleFonts.outfit(color: Colors.white70)),
                currentAccountPicture: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE91E8C)),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFF1A1A2E),
                    backgroundImage: (user?.photoUrl != null && user!.photoUrl!.isNotEmpty) ? NetworkImage(user.photoUrl!) : null,
                    child: (user?.photoUrl == null || user!.photoUrl!.isEmpty) ? const Icon(Icons.person, size: 40, color: Color(0xFFE91E8C)) : null,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.white70),
                title: Text("My Profile & Safety Settings", style: GoogleFonts.outfit(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined, color: Colors.white70),
                title: Text("Safety Guide & Privacy", style: GoogleFonts.outfit(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyGuideScreen()));
                },
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            user == null 
               ? const Center(child: CircularProgressIndicator()) 
               : _buildUnifiedDashboard(user),
            
            if (_isCountdownActive) _buildCountdownOverlay(),
            if (_isFakeCallCountdownActive) _buildFakeCallCountdownOverlay(user!),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "SOS TRIGGERING IN",
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text(
            "$_remainingSeconds",
            style: const TextStyle(color: Colors.red, fontSize: 120, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 60),
          ElevatedButton(
            onPressed: _cancelSosCountdown,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              minimumSize: const Size(200, 70),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
            ),
            child: const Text("CANCEL", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
          const Text(
            "Accidental press? Tap cancel now.",
            style: TextStyle(color: Colors.white60),
          )
        ],
      ),
    );
  }

  Widget _buildUnifiedDashboard(UserModel user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          // SOS Activation Zone
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  _sosActive ? "SOS ACTIVE — Sharing Location" : "Tap or SHAKE in emergency",
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    color: _sosActive ? const Color(0xFFE91E8C) : Colors.white38,
                    fontWeight: _sosActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 30),
                SosButton(onPressed: _sosActive ? () {} : _handleSosPress),
                const SizedBox(height: 20),
                if (_sosActive)
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _stopSos,
                        icon: const Icon(Icons.check_circle),
                        label: const Text("I am Safe — Stop SOS"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size(240, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _handleManualSirenPress(isFromSos: true),
                        icon: const Icon(Icons.notifications_active_rounded, color: Colors.redAccent),
                        label: Text("MANUAL SIREN", style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(240, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      Text("\"HELP SENTINEL\"", style: GoogleFonts.outfit(color: const Color(0xFFE91E8C), fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        onPressed: () => _sosService.callPolice(),
                        icon: const Icon(Icons.local_police),
                        label: Text("Call 999 (Police)", style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1A2E),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(200, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF2A2A40))),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _handleManualSirenPress(isFromSos: false),
                        icon: const Icon(Icons.notifications_active_rounded, color: Colors.white70),
                        label: Text("MANUAL SIREN", style: GoogleFonts.outfit(color: Colors.white70, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(200, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Colors.white10),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Biometric Monitor Banner
          _buildBiometricBanner(),

          const SizedBox(height: 16),

          // --- NEW Streamlined Fake Call Card ---
          _buildFakeCallCard(user),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFakeCallCard(UserModel user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleFakeCallPress,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_callback_rounded, color: Color(0xFF2196F3), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Panic Fake Call",
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Start a fake incoming call from ${user.fakeCallSenderName}",
                        style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF2196F3), size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BiometricDashboardScreen())),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF6C63FF).withValues(alpha: 0.2),
              const Color(0xFF00BCD4).withValues(alpha: 0.1),
            ],
          ),
          border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.4)),
          boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.15), blurRadius: 12)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.monitor_heart_rounded, color: Color(0xFF6C63FF), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Biometric Monitor',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 3),
                  Text('Heart Rate + Voice AI + Wristband',
                      style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF6C63FF), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildFakeCallCountdownOverlay(UserModel user) {
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.5), width: 2),
            ),
            child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF2196F3), size: 60),
          ),
          const SizedBox(height: 32),
          Text(
            "INCOMING CALL FROM",
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            user.fakeCallSenderName.toUpperCase(),
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 3),
          ),
          const SizedBox(height: 40),
          Text(
            "RINGING IN",
            style: GoogleFonts.outfit(color: const Color(0xFF2196F3), fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            "$_fakeCallRemainingSeconds",
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 80, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 60),
          ElevatedButton.icon(
            onPressed: _cancelFakeCall,
            icon: const Icon(Icons.cancel_rounded),
            label: const Text("CANCEL CALL"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A2A40),
              foregroundColor: Colors.white,
              minimumSize: const Size(200, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }
}
