import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state.dart';
import '../../../services/auth_service.dart';
import '../dashboard/dashboard_screen.dart';
import 'login_screen.dart';

class EmailOtpVerificationScreen extends StatefulWidget {
  const EmailOtpVerificationScreen({super.key});

  @override
  State<EmailOtpVerificationScreen> createState() => _EmailOtpVerificationScreenState();
}

class _EmailOtpVerificationScreenState extends State<EmailOtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final AuthService _auth = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _verify() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      _showError("Please enter the 6-digit code.");
      return;
    }

    setState(() => _isLoading = true);
    final appState = context.read<AppState>();
    final user = appState.currentUser;

    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      await _auth.verifyEmailOtp(user.email, code);
      // Refresh user state to mark as verified
      await appState.fetchUser(user.uid);
      // AuthWrapper in main.dart will automatically switch to DashboardScreen
    } catch (e) {
      if (mounted) _showError(e.toString());
      setState(() => _isLoading = false);
    }
  }

  void _resend() async {
    final user = context.read<AppState>().currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      await _auth.sendEmailOtp(user.email);
      _showSuccess("Code resent to ${user.email}");
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _logout() async {
    await _auth.signOut();
    // AuthWrapper will handle navigation to LoginScreen
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFFE53935),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF4CAF50),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: Colors.white38, size: 16),
            label: Text("LOGOUT", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E8C).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_unread_rounded, size: 60, color: Color(0xFFE91E8C)),
              ),
              const SizedBox(height: 32),
              Text(
                "Verify Your Email",
                style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                "A security code has been sent to:",
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
              ),
              Text(
                user?.email ?? "your email",
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _otpController,
                style: const TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: "000000",
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.05)),
                  counterText: "",
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF2A2A40))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE91E8C))),
                ),
              ),
              const SizedBox(height: 40),
              if (_isLoading)
                const CircularProgressIndicator(color: Color(0xFFE91E8C))
              else ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFE91E8C), Color(0xFF9C27B0)]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: const Color(0xFFE91E8C).withValues(alpha: 0.35), blurRadius: 20)],
                    ),
                    child: ElevatedButton(
                      onPressed: _verify,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: Text("VERIFY & CONTINUE", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: _resend,
                  child: Text("Didn't get a code? Resend", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
