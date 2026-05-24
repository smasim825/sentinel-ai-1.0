import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WristbandAnimationScreen extends StatefulWidget {
  const WristbandAnimationScreen({super.key});

  @override
  State<WristbandAnimationScreen> createState() =>
      _WristbandAnimationScreenState();
}

class _WristbandAnimationScreenState extends State<WristbandAnimationScreen>
    with TickerProviderStateMixin {
  // Step control
  int _step = 0; // 0=idle, 1=measuring, 2=spike, 3=keyword, 4=transmit, 5=sos
  bool _isPlaying = false;
  Timer? _stepTimer;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _dataPacketController;
  late AnimationController _sosFlashController;
  late AnimationController _btController;

  late Animation<double> _pulseAnim;
  late Animation<double> _sosFlashAnim;

  int _bpm = 72;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);

    _waveController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();

    _dataPacketController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));

    _sosFlashController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..repeat(reverse: true);

    _btController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _sosFlashAnim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(_sosFlashController);
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    _dataPacketController.dispose();
    _sosFlashController.dispose();
    _btController.dispose();
    super.dispose();
  }

  void _startDemo() {
    setState(() {
      _isPlaying = true;
      _step = 1;
      _bpm = 72;
    });

    // Step 2: HR Spike after 2s
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      setState(() { _step = 2; _bpm = 142; });
    });

    // Step 3: Keyword Detection after 2s more
    Future.delayed(const Duration(milliseconds: 4000), () {
      if (!mounted) return;
      setState(() { _step = 3; });
    });

    // Step 4: Transmit after 1.5s more
    Future.delayed(const Duration(milliseconds: 5500), () {
      if (!mounted) return;
      setState(() { _step = 4; });
      _dataPacketController.repeat();
    });

    // Step 5: SOS after 2s more
    Future.delayed(const Duration(milliseconds: 7500), () {
      if (!mounted) return;
      setState(() { _step = 5; });
      _dataPacketController.stop();
    });

    // Reset after 4s more
    Future.delayed(const Duration(milliseconds: 11500), () {
      if (!mounted) return;
      setState(() { _isPlaying = false; _step = 0; _bpm = 72; });
      _dataPacketController.reset();
    });
  }

  Color get _stepColor {
    switch (_step) {
      case 2: return const Color(0xFFFFD54F); // Warning Yellow
      case 3: return const Color(0xFFFF9800); // Danger Orange
      case 5: return const Color(0xFFFF1744); // SOS Red
      default: return const Color(0xFF6C63FF);
    }
  }

  String get _stepTitle {
    switch (_step) {
      case 0: return 'Sentinel Wristband';
      case 1: return 'Measuring Biometrics...';
      case 2: return '⚠ HEART RATE SPIKE';
      case 3: return '🎤 KEYWORD DETECTED';
      case 4: return '📡 Transmitting (2/4 Match)';
      case 5: return '🚨 SOS TRIGGERED!';
      default: return '';
    }
  }

  String get _stepDescription {
    switch (_step) {
      case 0:
        return 'Tap "Play Demo" to see how Sentinel uses multi-signal logic (2/4 conditions) to prevent false alarms.';
      case 1:
        return 'The wristband monitors pulse and skin response. AI filters out normal exercise vs. panic signals.';
      case 2:
        return 'HR jumped to 142 BPM. This alone does NOT trigger SOS to avoid false alarms from running or stress.';
      case 3:
        return 'User shouted "Bachao!". Voice AI confirms distress. We now have 2 matched conditions (HR + Voice).';
      case 4:
        return 'Since 2 conditions are met, the encrypted alert packet is sent to the phone immediately.';
      case 5:
        return 'App receives confirmed dual-signal alert. SOS triggers automatically: calls sent, location shared.';
      default:
        return '';
    }
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
        title: Text('How It Works',
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Step indicator
            _buildStepIndicator(),
            const SizedBox(height: 24),

            // Main animation canvas
            _buildAnimationCanvas(),
            const SizedBox(height: 24),

            // Title and description
            _buildStepInfo(),
            const SizedBox(height: 24),

            // Data flow diagram
            _buildDataFlowRow(),
            const SizedBox(height: 24),

            // Tech specs
            _buildTechSpecs(),
            const SizedBox(height: 24),

            // Play button
            _buildPlayButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Idle', 'Measure', 'Detect', 'Distress', 'Transmit', 'SOS'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (i) {
        // Step mapping to account for added step
        int displayStep = _step;
        final active = i == displayStep;
        final done = i < displayStep;
        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: active ? 32 : 24,
              height: active ? 32 : 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? const Color(0xFF00E676)
                    : active
                        ? _stepColor
                        : Colors.white12,
                border: Border.all(
                    color: active ? _stepColor : Colors.transparent, width: 2),
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check, color: Colors.white, size: 12)
                    : Text('${i + 1}',
                        style: GoogleFonts.outfit(
                            color: active ? Colors.white : Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
              ),
            ),
            if (i < steps.length - 1)
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 22,
                height: 2,
                color: i < displayStep ? const Color(0xFF00E676) : Colors.white12,
              ),
          ],
        );
      }),
    );
  }

  Widget _buildAnimationCanvas() {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1526),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _stepColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: _stepColor.withValues(alpha: 0.1), blurRadius: 20),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background grid
            CustomPaint(
              size: const Size(double.infinity, double.infinity),
              painter: _GridPainter(),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // LEFT: Wristband
                _buildWristbandWidget(),

                // CENTER: Bluetooth beam
                _buildBluetoothBeam(),

                // RIGHT: Phone
                _buildPhoneWidget(),
              ],
            ),

            // SOS overlay
            if (_step == 5)
              AnimatedBuilder(
                animation: _sosFlashAnim,
                builder: (_, __) => Container(
                  color: Colors.red.withValues(alpha: _sosFlashAnim.value * 0.15),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWristbandWidget() {
    final hrColor = _step >= 2 ? (_step == 2 ? const Color(0xFFFFD54F) : const Color(0xFFFF4444)) : const Color(0xFF00E676);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Wrist + band
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) => Transform.scale(
            scale: _step >= 1 ? _pulseAnim.value : 1.0,
            child: child,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple rings
              if (_step >= 1)
                AnimatedBuilder(
                  animation: _waveController,
                  builder: (_, __) => Stack(
                    alignment: Alignment.center,
                    children: [1, 2, 3].map((i) {
                      final progress = (_waveController.value + i * 0.33) % 1.0;
                      return Opacity(
                        opacity: (1 - progress) * 0.4,
                        child: Container(
                          width: 60 + progress * 40,
                          height: 60 + progress * 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: hrColor, width: 1.5),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              // Band
              Container(
                width: 64,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: _step >= 2
                        ? (_step == 2 ? [const Color(0xFF5D4037), const Color(0xFFFFD54F)] : [const Color(0xFF8B0000), const Color(0xFFFF4444)])
                        : [const Color(0xFF1A1A5E), const Color(0xFF6C63FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(color: hrColor.withValues(alpha: 0.5), blurRadius: 12)],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.watch, color: Colors.white, size: 20),
                    const SizedBox(height: 4),
                    Text('$_bpm',
                        style: GoogleFonts.outfit(
                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    Text('BPM',
                        style: GoogleFonts.outfit(color: Colors.white60, fontSize: 8)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Sensor label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: hrColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: hrColor.withValues(alpha: 0.4)),
          ),
          child: Text(_step == 2 ? '⚠ WARNING' : _step >= 3 ? '🚨 DANGER' : _step >= 1 ? '● SENSING' : '○ IDLE',
              style: GoogleFonts.outfit(color: hrColor, fontSize: 9, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        Text('Wristband', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  Widget _buildBluetoothBeam() {
    return SizedBox(
      width: 80,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // BT icon
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _btController,
                builder: (_, __) => Opacity(
                  opacity: _step >= 4 ? 0.5 + 0.5 * sin(_btController.value * 2 * pi) : 0.2,
                  child: const Icon(Icons.bluetooth, color: Color(0xFF00BCD4), size: 20),
                ),
              ),
              const SizedBox(height: 4),
              Text('BLE', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 9)),
            ],
          ),
          // Moving data packets
          if (_step == 4)
            AnimatedBuilder(
              animation: _dataPacketController,
              builder: (_, __) {
                final t = _dataPacketController.value;
                return Positioned(
                  left: 10 + t * 60,
                  child: Opacity(
                    opacity: t < 0.8 ? 1.0 : 1 - (t - 0.8) / 0.2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00BCD4),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPhoneWidget() {
    final activeColor = _step == 5 ? const Color(0xFFFF1744) : (_step >= 3 ? const Color(0xFFFF9800) : const Color(0xFF6C63FF));
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF1A1A2E),
            border: Border.all(
              color: _step >= 4 ? activeColor : Colors.white12,
              width: _step >= 4 ? 2 : 1,
            ),
            boxShadow: _step >= 4
                ? [BoxShadow(color: activeColor.withValues(alpha: 0.5), blurRadius: 16)]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_step == 5)
                AnimatedBuilder(
                  animation: _sosFlashAnim,
                  builder: (_, __) => Opacity(
                    opacity: _sosFlashAnim.value,
                    child: const Text('🚨', style: TextStyle(fontSize: 22)),
                  ),
                )
              else if (_step >= 3)
                const Icon(Icons.mic, color: Color(0xFFFF9800), size: 20)
              else
                const Icon(Icons.phone_android, color: Colors.white38, size: 20),
              const SizedBox(height: 4),
              Text(
                _step == 5 ? 'SOS!' : (_step >= 3 ? 'Distress!' : 'App'),
                style: GoogleFonts.outfit(
                    color: _step == 5
                        ? const Color(0xFFFF1744)
                        : (_step >= 3 ? const Color(0xFFFF9800) : Colors.white38),
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (_step >= 4 ? activeColor : Colors.white12).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: (_step >= 4 ? activeColor : Colors.white12).withValues(alpha: 0.4)),
          ),
          child: Text(
            _step == 5 ? '🚨 SOS' : (_step >= 4 ? '● RECEIVED' : '○ STANDBY'),
            style: GoogleFonts.outfit(
                color: _step >= 4 ? activeColor : Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Text('Sentinel App', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  Widget _buildStepInfo() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(
        key: ValueKey(_step),
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1526),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _stepColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_stepTitle,
                style: GoogleFonts.outfit(
                    color: _stepColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_stepDescription,
                style: GoogleFonts.outfit(
                    color: Colors.white60, fontSize: 13, height: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildDataFlowRow() {
    final items = [
      {'icon': '💓', 'label': 'Optical\nSensor', 'sub': 'HR & SpO2'},
      {'icon': '⚡', 'label': 'GSR\nSensor', 'sub': 'Skin Conductance'},
      {'icon': '📡', 'label': 'Bluetooth\nLE 5.0', 'sub': 'Data Transfer'},
      {'icon': '🤖', 'label': 'AI\nEngine', 'sub': 'Fear Detection'},
      {'icon': '🚨', 'label': 'Auto\nSOS', 'sub': 'Guardian Alert'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.account_tree_rounded, color: Color(0xFF6C63FF), size: 14),
          const SizedBox(width: 8),
          Text('HOW THE SYSTEM WORKS',
              style: GoogleFonts.outfit(
                  color: Colors.white38, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              return Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1526),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
                        ),
                        child: Center(
                          child: Text(item['icon']!, style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(item['label']!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      Text(item['sub']!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 9)),
                    ],
                  ),
                  if (i < items.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24, left: 4, right: 4),
                      child: Icon(Icons.arrow_forward_ios_rounded,
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.5), size: 12),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTechSpecs() {
    final specs = [
      {'label': 'Sensor Type', 'value': 'PPG Optical + GSR Electrodes'},
      {'label': 'Sampling Rate', 'value': '50Hz (50 readings/second)'},
      {'label': 'Connectivity', 'value': 'Bluetooth Low Energy 5.0'},
      {'label': 'Battery Life', 'value': '72 hours continuous monitoring'},
      {'label': 'Detection AI', 'value': 'On-device TFLite Model'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1526),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.memory, color: Color(0xFF00BCD4), size: 14),
            const SizedBox(width: 8),
            Text('TECHNICAL SPECIFICATIONS',
                style: GoogleFonts.outfit(
                    color: Colors.white38, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 14),
          ...specs.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(s['label']!,
                        style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
                    Text(s['value']!,
                        style: GoogleFonts.outfit(
                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: _isPlaying ? null : _startDemo,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: _isPlaying
              ? const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF1A1A2E)])
              : const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF00BCD4)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          boxShadow: _isPlaying
              ? []
              : [const BoxShadow(color: Color(0x556C63FF), blurRadius: 20, offset: Offset(0, 6))],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_isPlaying ? Icons.hourglass_top : Icons.play_circle_filled,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                _isPlaying ? 'Demo running...' : '▶  Play Demo for Judges',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Background grid painter
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
