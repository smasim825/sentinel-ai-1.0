import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

class InboundCallOverlay extends StatefulWidget {
  final String name;
  final String number;
  final bool isIos;

  const InboundCallOverlay({
    super.key,
    required this.name,
    required this.number,
    required this.isIos,
  });

  @override
  State<InboundCallOverlay> createState() => _InboundCallOverlayState();
}

class _InboundCallOverlayState extends State<InboundCallOverlay> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _vibrationTimer;
  bool _isAccepted = false;
  int _callDuration = 0;
  Timer? _callDurationTimer;

  @override
  void initState() {
    super.initState();
    _startAlerts();
  }

  void _startAlerts() async {
    // 1. Vibration
    if (!kIsWeb) {
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
          Vibration.vibrate(duration: 1000);
        });
      }
    }

    // 2. Sound (Generic Ringtone URL)
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      // Using a generic standard ringtone sound
      await _audioPlayer.play(UrlSource('https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'));
    } catch (e) {
      debugPrint("Audio Play Error: $e");
    }
  }

  void _stopAlerts() {
    _vibrationTimer?.cancel();
    _audioPlayer.stop();
  }

  void _acceptCall() {
    _stopAlerts();
    setState(() {
      _isAccepted = true;
    });
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _callDuration++);
      }
    });
  }

  void _declineCall() {
    _stopAlerts();
    _callDurationTimer?.cancel();
    Navigator.pop(context);
  }

  String _formatDuration(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _stopAlerts();
    _callDurationTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isAccepted ? _buildActiveCallUI() : _buildIncomingCallUI(),
    );
  }

  Widget _buildIncomingCallUI() {
    return widget.isIos ? _buildIosIncoming() : _buildAndroidIncoming();
  }

  Widget _buildIosIncoming() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey.shade900, Colors.black],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 80),
            Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.normal)),
            const SizedBox(height: 8),
            const Text("incoming call...", style: TextStyle(color: Colors.white60, fontSize: 18)),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 60, left: 40, right: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   _buildCallButton(Icons.call_end, Colors.red, "Decline", _declineCall, true),
                   _buildCallButton(Icons.call, Colors.green, "Accept", _acceptCall, true),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAndroidIncoming() {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 60),
          const CircleAvatar(
            radius: 50,
            backgroundColor: Colors.blueGrey,
            child: Icon(Icons.person, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          Text(widget.number, style: const TextStyle(color: Colors.white70, fontSize: 18)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCallButton(Icons.call_end, Colors.red, "Decline", _declineCall, false),
                _buildCallButton(Icons.call, Colors.green, "Accept", _acceptCall, false),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActiveCallUI() {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 32)),
          const SizedBox(height: 8),
          Text(_formatDuration(_callDuration), style: const TextStyle(color: Colors.white70, fontSize: 18)),
          const Spacer(),
          // Placeholder grid for call options
          _buildCallOptionGrid(),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 50),
            child: CircleAvatar(
              radius: 35,
              backgroundColor: Colors.red,
              child: IconButton(
                icon: const Icon(Icons.call_end, color: Colors.white, size: 30),
                onPressed: _declineCall,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCallOptionGrid() {
    return Wrap(
      spacing: 40,
      runSpacing: 40,
      alignment: WrapAlignment.center,
      children: [
        _buildIconLabel(Icons.mic_off, "mute"),
        _buildIconLabel(Icons.dialpad, "keypad"),
        _buildIconLabel(Icons.volume_up, "speaker"),
        _buildIconLabel(Icons.add, "add call"),
        _buildIconLabel(Icons.video_call, "FaceTime"),
        _buildIconLabel(Icons.contact_phone, "contacts"),
      ],
    );
  }

  Widget _buildIconLabel(IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _buildCallButton(IconData icon, Color color, String label, VoidCallback onTap, bool isIos) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
            child: Icon(icon, color: Colors.white, size: 35),
          ),
        ),
        if (isIos) const SizedBox(height: 8),
        if (isIos) Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }
}
