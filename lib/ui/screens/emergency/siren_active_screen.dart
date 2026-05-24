import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state.dart';
import '../../../services/alarm_service.dart';

class SirenActiveScreen extends StatefulWidget {
  final bool isFromSos;
  const SirenActiveScreen({super.key, this.isFromSos = false});

  @override
  State<SirenActiveScreen> createState() => _SirenActiveScreenState();
}

class _SirenActiveScreenState extends State<SirenActiveScreen> {
  late Timer _timer;
  int _remainingSeconds = 180; // 3 minutes
  final AlarmService _alarmService = AlarmService();
  
  bool _showingPassword1 = false;
  bool _showingPassword2 = false;
  final TextEditingController _passController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _stopEverything();
      }
    });
  }

  void _stopEverything() {
    _timer.cancel();
    _alarmService.stopSiren();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _extendTime() {
    setState(() {
      _remainingSeconds += 120; // Add 2 minutes
    });
  }

  void _handleStopPress() {
    final appState = context.read<AppState>();
    final user = appState.currentUser;

    if (user?.sirenPassword1 == null || user?.sirenPassword2 == null) {
      // If no passwords set, allow stop (emergency fallback)
      _stopEverything();
      return;
    }

    setState(() {
      _showingPassword1 = true;
      _passController.clear();
      _errorMessage = null;
    });
  }

  void _verifyPassword1() {
    final appState = context.read<AppState>();
    if (appState.verifySirenPassword1(_passController.text)) {
      setState(() {
        _showingPassword1 = false;
        _showingPassword2 = true;
        _passController.clear();
        _errorMessage = null;
      });
    } else {
      setState(() => _errorMessage = "Incorrect Password 1");
    }
  }

  void _verifyPassword2() {
    final appState = context.read<AppState>();
    if (appState.verifySirenPassword2(_passController.text)) {
      _stopEverything();
    } else {
      setState(() => _errorMessage = "Incorrect Password 2");
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    String seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');

    return WillPopScope(
      onWillPop: () async => false, // Prevent accidental back
      child: Scaffold(
        backgroundColor: const Color(0xFF7B0000), // Emergency Red
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 100, color: Colors.white),
                  const SizedBox(height: 20),
                  Text(
                    "EMERGENCY SIREN ACTIVE",
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    "$minutes:$seconds",
                    style: GoogleFonts.outfit(
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 60),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 80,
                          child: ElevatedButton(
                            onPressed: _handleStopPress,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: Text(
                              "STOP SIREN",
                              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: _extendTime,
                          child: Text(
                            "EXTEND +2 MIN",
                            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_showingPassword1 || _showingPassword2)
                Container(
                  color: Colors.black.withOpacity(0.9),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _showingPassword1 ? "ENTER PASSWORD 1" : "ENTER PASSWORD 2",
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _passController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white10,
                              errorText: _errorMessage,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => setState(() {
                                    _showingPassword1 = false;
                                    _showingPassword2 = false;
                                  }),
                                  child: const Text("CANCEL", style: TextStyle(color: Colors.white54)),
                                ),
                              ),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _showingPassword1 ? _verifyPassword1 : _verifyPassword2,
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  child: const Text("VERIFY"),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
