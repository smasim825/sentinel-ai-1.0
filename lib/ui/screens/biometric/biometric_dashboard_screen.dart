import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'wristband_animation_screen.dart';
import '../../../services/sos_service.dart';
import '../../../services/auth_service.dart';

class BiometricDashboardScreen extends StatefulWidget {
  const BiometricDashboardScreen({super.key});

  @override
  State<BiometricDashboardScreen> createState() => _BiometricDashboardScreenState();
}

class _BiometricDashboardScreenState extends State<BiometricDashboardScreen>
    with TickerProviderStateMixin {

  // Heart Rate State
  int _bpm = 72;
  bool _isSpiked = false;
  bool _isVoiceListening = true;
  bool _isKeywordDetected = false;
  bool _isSkinConductanceHigh = false; // Signal 3: galvanic skin response
  bool _isWristShaken = false;          // Signal 4: panic shake gesture

  Timer? _heartbeatTimer;
  Timer? _pulseTimer;

  late AnimationController _heartPulseController;
  late AnimationController _waveController;
  late Animation<double> _heartPulseAnim;

  final Random _random = Random();

  // Detection Log
  final List<Map<String, dynamic>> _logs = [];
  final ScrollController _logScrollController = ScrollController();

  void _addLog(String message, {Color color = const Color(0xFF00E676)}) {
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    setState(() {
      _logs.insert(0, {'time': time, 'message': message, 'color': color});
      if (_logs.length > 50) _logs.removeLast();
    });
  }

  @override
  void initState() {
    super.initState();

    _heartPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _heartPulseAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _heartPulseController, curve: Curves.easeOut),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _startHeartbeat();
    _addLog('Biometric monitor initialized');
    _addLog('Microphone active — listening for keywords in Bangla/English');
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    final interval = _isSpiked ? 300 : 833; // 200bpm vs 72bpm
    _heartbeatTimer = Timer.periodic(Duration(milliseconds: interval), (_) {
      _heartPulseController.forward().then((_) => _heartPulseController.reverse());
      if (mounted) {
        setState(() {
          _bpm = _isSpiked
              ? 130 + _random.nextInt(40)
              : 68 + _random.nextInt(10);
        });
      }
    });
  }

  void _spikeHeartRate() {
    setState(() => _isSpiked = true);
    _startHeartbeat();
    _addLog('⚠ Heart rate elevated — $_bpm BPM detected', color: const Color(0xFFFF4444));
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) _normalizeHeartRate();
    });
  }

  void _normalizeHeartRate() {
    setState(() => _isSpiked = false);
    _startHeartbeat();
    _addLog('Heart rate normalized — $_bpm BPM', color: const Color(0xFF00E676));
  }

  void _simulateKeyword() {
    setState(() => _isKeywordDetected = true);
    _addLog('🎤 Keyword detected: "Bachao" / "Help"', color: const Color(0xFFFF4444));
    _checkAndLogSosStatus();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _isKeywordDetected = false);
        _addLog('Voice signal cleared', color: Colors.white38);
      }
    });
  }

  void _simulateSkinConductance() {
    setState(() => _isSkinConductanceHigh = true);
    _addLog('⚡ Skin conductance spike — stress/fear detected', color: const Color(0xFFFF9800));
    _checkAndLogSosStatus();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _isSkinConductanceHigh = false);
        _addLog('Skin conductance normalized', color: Colors.white38);
      }
    });
  }

  void _simulateWristShake() {
    setState(() => _isWristShaken = true);
    _addLog('📳 Panic shake detected on wristband!', color: const Color(0xFFFF9800));
    _checkAndLogSosStatus();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _isWristShaken = false);
        _addLog('Shake signal cleared', color: Colors.white38);
      }
    });
  }

  void _checkAndLogSosStatus() async {
    // Small delay to let setState finish if needed, or just check the count
    final count = _signalCount;
    
    if (count == 1) {
      _addLog('⚠ WARNING: 1/4 signal detected — monitoring closely', color: const Color(0xFFFFD54F));
    } else if (count >= 2) {
      _addLog('🚨 THRESHOLD REACHED: $count/4 signals — SOS TRIGGERED!', color: const Color(0xFFFF1744));
      
      // AUTO TRIGGER REAL SOS
      try {
        // We trigger it directly for the demo; the service handles state
        final auth = AuthService();
        final user = await auth.getCurrentUser();
        if (user != null) {
          final sos = SosService();
          await sos.triggerSos(user.uid, user.name, user.guardianPhones);
        }
      } catch (e) {
        debugPrint("Error triggering auto-SOS: $e");
      }
    }
  }

  // Count how many of the 4 signals are currently active
  int get _signalCount =>
      (_isSpiked ? 1 : 0) +
      (_isKeywordDetected ? 1 : 0) +
      (_isSkinConductanceHigh ? 1 : 0) +
      (_isWristShaken ? 1 : 0);

  // SOS triggers if 2 or more of 4 signals confirmed
  bool get _isAtRisk => _signalCount >= 2;

  // Warning if exactly 1 signal
  bool get _isWarning => _signalCount == 1;

  Color get _hrColor => _isSpiked ? const Color(0xFFFF4444) : const Color(0xFF00E676);
  String get _hrStatus => _isSpiked ? '⚠ ELEVATED' : '● NORMAL';

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _pulseTimer?.cancel();
    _heartPulseController.dispose();
    _waveController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B14),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Biometric Monitor',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2340),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.4)),
            ),
            child: Text(
              '⌚ WRISTBAND',
              style: GoogleFonts.outfit(
                color: const Color(0xFF6C63FF),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            if (_isAtRisk) _buildRiskBanner(),
            if (_isAtRisk) const SizedBox(height: 16),

            // Top Row: HR + Voice
            Row(
              children: [
                Expanded(child: _buildHeartRateCard()),
                const SizedBox(width: 12),
                Expanded(child: _buildVoiceCard()),
              ],
            ),
            const SizedBox(height: 16),

            // Quad-Signal Confirmation Panel
            _buildQuadConfirmationPanel(),
            const SizedBox(height: 16),

            // How It Works animated explainer button
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const WristbandAnimationScreen())),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00BCD4), Color(0xFF6C63FF)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.35), blurRadius: 16),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_circle_filled, color: Colors.white, size: 24),
                    const SizedBox(width: 10),
                    Text('▶  How Wristband Works — Animated Demo',
                        style: GoogleFonts.outfit(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Wristband Info Card
            _buildWristbandInfoCard(),
            const SizedBox(height: 16),

            // Demo Controls
            _buildDemoControls(),
            const SizedBox(height: 16),

            // Detection Log
            _buildDetectionLog(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF1744), Color(0xFFAA00FF)],
        ),
        boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 20)],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🚨 HIGH RISK DETECTED',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Multiple signals confirmed — SOS triggered',
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeartRateCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1526),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _hrColor.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: _hrColor.withValues(alpha: 0.1), blurRadius: 15)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ScaleTransition(
              scale: _heartPulseAnim,
              child: Icon(Icons.favorite, color: _hrColor, size: 20),
            ),
            const SizedBox(width: 8),
            Text('HEART RATE',
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11, letterSpacing: 1.5)),
          ]),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$_bpm',
                  style: GoogleFonts.outfit(
                      color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, height: 1)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('BPM',
                    style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Mini pulse bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (_, __) => LinearProgressIndicator(
                value: _isSpiked
                    ? 0.5 + 0.5 * sin(_waveController.value * 2 * pi)
                    : 0.2 + 0.15 * sin(_waveController.value * 2 * pi),
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(_hrColor),
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _hrColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _hrColor.withValues(alpha: 0.4)),
            ),
            child: Text(_hrStatus,
                style: GoogleFonts.outfit(color: _hrColor, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1526),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isKeywordDetected
              ? const Color(0xFFFF4444).withValues(alpha: 0.5)
              : _isVoiceListening
                  ? const Color(0xFF00E676).withValues(alpha: 0.3)
                  : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              Icons.mic,
              color: _isKeywordDetected
                  ? const Color(0xFFFF4444)
                  : _isVoiceListening
                      ? const Color(0xFF00E676)
                      : Colors.white38,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text('VOICE LISTEN',
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11, letterSpacing: 1.5)),
          ]),
          const SizedBox(height: 12),
          Text(
            _isKeywordDetected ? 'KEYWORD\nDETECTED!' : _isVoiceListening ? 'Active' : 'Stopped',
            style: GoogleFonts.outfit(
              color: _isKeywordDetected ? const Color(0xFFFF4444) : Colors.white,
              fontSize: _isKeywordDetected ? 20 : 28,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          // Sound wave dots
          AnimatedBuilder(
            animation: _waveController,
            builder: (_, __) {
              return Row(
                children: List.generate(5, (i) {
                  double h = _isVoiceListening
                      ? 4 + 10 * ((sin(_waveController.value * 2 * pi + i * 0.8) + 1) / 2)
                      : 4;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: 4,
                      height: h,
                      decoration: BoxDecoration(
                        color: _isKeywordDetected
                            ? const Color(0xFFFF4444)
                            : const Color(0xFF00E676),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
            ),
            child: Text('● LISTENING',
                style: GoogleFonts.outfit(
                    color: const Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuadConfirmationPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1526),
             border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.lock, color: Color(0xFF6C63FF), size: 16),
            const SizedBox(width: 8),
            Text('QUAD-SIGNAL CONFIRMATION (2/4 = SOS)',
                style: GoogleFonts.outfit(
                    color: Colors.white54, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          _buildConfirmRow(icon: Icons.favorite, label: 'Heart Rate Spike',
              isActive: _isSpiked, activeLabel: '>120 BPM', inactiveLabel: 'OK'),
          const Divider(color: Colors.white10, height: 20),
          _buildConfirmRow(icon: Icons.mic, label: 'Voice Keyword',
              isActive: _isKeywordDetected, activeLabel: 'DETECTED', inactiveLabel: 'OK'),
          const Divider(color: Colors.white10, height: 20),
          _buildConfirmRow(icon: Icons.electric_bolt, label: 'Skin Conductance',
              isActive: _isSkinConductanceHigh, activeLabel: 'SPIKED', inactiveLabel: 'OK'),
          const Divider(color: Colors.white10, height: 20),
          _buildConfirmRow(icon: Icons.vibration, label: 'Wristband Shake',
              isActive: _isWristShaken, activeLabel: 'SHAKEN', inactiveLabel: 'OK'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Signals confirmed',
                  style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13)),
              Text(
                '$_signalCount / 4',
                style: GoogleFonts.outfit(
                    color: _isAtRisk
                        ? const Color(0xFFFF4444)
                        : _isWarning
                            ? const Color(0xFFFFD54F)
                            : Colors.white38,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (_isWarning && !_isAtRisk) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.5)),
              ),
              child: Center(
                child: Text('⚠ WARNING — 1/4 signal. Monitoring closely...',
                    style: GoogleFonts.outfit(
                        color: const Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
          if (_isAtRisk) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  const Color(0xFFFF1744).withValues(alpha: 0.2),
                  const Color(0xFFAA00FF).withValues(alpha: 0.2),
                ]),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFF1744).withValues(alpha: 0.4)),
              ),
              child: Center(
                child: Text('🚨 $_signalCount/4 CONFIRMED — AUTO SOS TRIGGERED',
                    style: GoogleFonts.outfit(
                        color: const Color(0xFFFF4444), fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildConfirmRow({
    required IconData icon,
    required String label,
    required bool isActive,
    required String activeLabel,
    required String inactiveLabel,
  }) {
    final color = isActive ? const Color(0xFFFF4444) : const Color(0xFF00E676);
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 15)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            isActive ? '✗ $activeLabel' : '✓ $inactiveLabel',
            style: GoogleFonts.outfit(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildWristbandInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C63FF).withValues(alpha: 0.15),
            const Color(0xFF00BCD4).withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.watch, color: Color(0xFF6C63FF), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sentinel Wristband (Concept)',
                    style: GoogleFonts.outfit(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  'A custom IoT wristband will connect via Bluetooth and send real-time heart rate & skin conductance data to trigger SOS automatically.',
                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.science, color: Color(0xFFFFD54F), size: 14),
          const SizedBox(width: 6),
          Text('DEMO CONTROLS (FOR PRESENTATION)',
              style: GoogleFonts.outfit(
                  color: const Color(0xFFFFD54F), fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        // Row 1: Heart Rate
        Row(
          children: [
            Expanded(child: _buildDemoButton(
              label: 'Spike Heart Rate',
              icon: Icons.favorite,
              color: const Color(0xFFFF4444),
              onTap: _spikeHeartRate,
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildDemoButton(
              label: 'Normalize HR',
              icon: Icons.favorite_border,
              color: const Color(0xFF00E676),
              onTap: _normalizeHeartRate,
            )),
          ],
        ),
        const SizedBox(height: 10),
        // Row 2: Voice
        Row(
          children: [
            Expanded(child: _buildDemoButton(
              label: 'Simulate Keyword',
              icon: Icons.mic,
              color: const Color(0xFF00BCD4),
              onTap: _simulateKeyword,
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildDemoButton(
              label: _isVoiceListening ? 'Stop Microphone' : 'Start Microphone',
              icon: _isVoiceListening ? Icons.mic_off : Icons.mic,
              color: const Color(0xFFFF9800),
              onTap: () {
                setState(() => _isVoiceListening = !_isVoiceListening);
                _addLog(
                  !_isVoiceListening
                      ? 'Microphone stopped'
                      : 'Microphone active — listening for keywords in Bangla/English',
                  color: !_isVoiceListening ? Colors.white38 : const Color(0xFF00E676),
                );
              },
            )),
          ],
        ),
        const SizedBox(height: 10),
        // Row 3: Biometric Sensors
        Row(
          children: [
            Expanded(child: _buildDemoButton(
              label: 'Simulate Skin Conductance',
              icon: Icons.electric_bolt,
              color: const Color(0xFFFF9800),
              onTap: _simulateSkinConductance,
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildDemoButton(
              label: 'Simulate Wrist Shake',
              icon: Icons.vibration,
              color: const Color(0xFF9C27B0),
              onTap: _simulateWristShake,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: Text('Or speak into your microphone — keywords trigger automatically',
              style: GoogleFonts.outfit(color: Colors.white24, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _buildDetectionLog() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF080B14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.terminal, color: Color(0xFF6C63FF), size: 14),
                const SizedBox(width: 8),
                Text('DETECTION LOG',
                    style: GoogleFonts.outfit(
                        color: Colors.white54, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              ]),
              GestureDetector(
                onTap: () => setState(() => _logs.clear()),
                child: Text('CLEAR',
                    style: GoogleFonts.outfit(
                        color: Colors.white24, fontSize: 10, letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFF0A0D18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _logs.isEmpty
                ? Center(
                    child: Text('No events yet — tap demo controls to start',
                        style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12)),
                  )
                : ListView.builder(
                    controller: _logScrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log['time'],
                              style: GoogleFonts.robotoMono(
                                  color: Colors.white24, fontSize: 11),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                log['message'],
                                style: GoogleFonts.robotoMono(
                                    color: log['color'], fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  color: color, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
