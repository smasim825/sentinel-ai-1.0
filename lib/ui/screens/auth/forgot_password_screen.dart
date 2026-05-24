import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/auth_service.dart';

enum RecoveryStep { enterEmail, enterOtp, resetPassword }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  final _formKey = GlobalKey<FormState>();
  final AuthService _auth = AuthService();
  
  RecoveryStep _currentStep = RecoveryStep.enterEmail;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError("Please enter a valid email address.");
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      await _auth.sendEmailOtp(email);
      setState(() {
        _currentStep = RecoveryStep.enterOtp;
        _isLoading = false;
      });
      _showSuccess("Security code sent to your email!");
    } catch (e) {
      _showError(e.toString());
      setState(() => _isLoading = false);
    }
  }

  void _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showError("Enter the 6-digit code.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.verifyEmailOtp(_emailController.text.trim(), otp, persist: true);
      setState(() {
        _currentStep = RecoveryStep.resetPassword;
        _isLoading = false;
      });
    } catch (e) {
      _showError(e.toString());
      setState(() => _isLoading = false);
    }
  }

  void _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError("Passwords do not match.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.resetPasswordWithOtp(
        _emailController.text.trim(),
        _otpController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted) {
        _showSuccess("Password reset successfully! You can now log in with your new password.");
        Navigator.pop(context); // Go back to login
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        title: Text("Recover Account", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: _buildStepContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case RecoveryStep.enterEmail:
        return _buildEmailStep();
      case RecoveryStep.enterOtp:
        return _buildOtpStep();
      case RecoveryStep.resetPassword:
        return _buildPasswordStep();
    }
  }

  Widget _buildEmailStep() {
    return Column(
      key: const ValueKey('emailStep'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Center(child: _headerIcon(Icons.email_outlined)),
        const SizedBox(height: 32),
        Text("Forget Password?", textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 12),
        Text("Enter your registered email address to receive a 6-digit security code.", textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 15, color: Colors.white38)),
        const SizedBox(height: 48),
        TextFormField(
          controller: _emailController,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDecoration("Email Address", Icons.email_rounded),
        ),
        const SizedBox(height: 32),
        _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E8C))) : _actionButton("SEND CODE", _sendOtp),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      key: const ValueKey('otpStep'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Text("Verify Email", textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 8),
        Text("Enter the 6-digit code sent to ${_emailController.text}", textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 15, color: Colors.white38)),
        const SizedBox(height: 40),
        TextFormField(
          controller: _otpController,
          style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: _inputDecoration("6-Digit Code", Icons.security_rounded).copyWith(counterText: ""),
        ),
        const SizedBox(height: 32),
        _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E8C))) : _actionButton("VERIFY OTP", _verifyOtp),
        TextButton(onPressed: () => setState(() => _currentStep = RecoveryStep.enterEmail), child: const Text("Use different email", style: TextStyle(color: Colors.white38))),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('passwordStep'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Text("Set New Password", textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 40),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("New Password", Icons.lock_outline_rounded),
            validator: (v) => (v == null || v.length < 6) ? "Minimum 6 characters" : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("Confirm Password", Icons.lock_reset_rounded),
          ),
          const SizedBox(height: 40),
          _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E8C))) : _actionButton("RESET PASSWORD", _resetPassword),
        ],
      ),
    );
  }

  Widget _headerIcon(IconData icon) {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFFE91E8C), Color(0xFF9C27B0)]), boxShadow: [BoxShadow(color: const Color(0xFFE91E8C).withValues(alpha: 0.4), blurRadius: 24)]),
      child: Icon(icon, color: Colors.white, size: 40),
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed) {
    return Container(
      height: 56,
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE91E8C), Color(0xFF9C27B0)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFFE91E8C).withValues(alpha: 0.35), blurRadius: 20)]),
      child: ElevatedButton(onPressed: onPressed, style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white))),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.white38),
      filled: true,
      fillColor: const Color(0xFF1A1A2E),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF2A2A40))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE91E8C))),
    );
  }
}
