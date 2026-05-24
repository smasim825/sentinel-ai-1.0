import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:image_picker/image_picker.dart';
import '../../../providers/app_state.dart';
import '../../../services/auth_service.dart';
import '../dashboard/dashboard_screen.dart';

enum RegisterStep { details, verifyOtp }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  
  bool _phoneValid = false;
  RegisterStep _currentStep = RegisterStep.details;
  final AuthService _auth = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  Uint8List? _profileImage;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 512);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _profileImage = bytes);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_phoneValid || _phoneController.text.isEmpty) {
      _showError("Please enter a valid phone number.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.sendPreRegistrationOtp(
        _emailController.text.trim(),
        _nameController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _currentStep = RegisterStep.verifyOtp;
          _isLoading = false;
        });
        _showSuccess("Security code sent to your email!");
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
      setState(() => _isLoading = false);
    }
  }

  void _verifyAndComplete() async {
    final emailOtp = _otpController.text.trim();
    
    if (emailOtp.length != 6) {
      _showError("Please enter the 6-digit code.");
      return;
    }

    setState(() => _isLoading = true);
    final appState = context.read<AppState>();

    try {
      // Complete registration and verify OTP all in one step
      final user = await _auth.completeRegistration(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _phoneController.text.trim(),
        _passwordController.text.trim(),
        emailOtp,
        photoBytes: _profileImage,
      );
      
      if (user != null && mounted) {
        await appState.fetchUser(user.uid);
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
      setState(() => _isLoading = false);
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
        title: Text(_currentStep == RegisterStep.details ? "Create Account" : "Verify Email", 
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: _currentStep == RegisterStep.details ? _buildDetailsForm() : _buildOtpForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsForm() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('details'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [Color(0xFFE91E8C), Color(0xFF9C27B0)]),
                      boxShadow: [BoxShadow(color: const Color(0xFFE91E8C).withValues(alpha: 0.4), blurRadius: 20)],
                    ),
                    child: ClipOval(
                      child: _profileImage != null
                          ? Image.memory(_profileImage!, fit: BoxFit.cover)
                          : const Icon(Icons.person, color: Colors.white, size: 40),
                    ),
                  ),
                  Positioned(bottom: 0, right: 0, child: _cameraIcon()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("Full Name", Icons.person_outline_rounded),
            validator: (v) => (v == null || v.isEmpty) ? "Enter name" : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("Email Address", Icons.email_outlined),
            validator: (v) => (v == null || !v.contains('@')) ? "Enter valid email" : null,
          ),
          const SizedBox(height: 16),
          IntlPhoneField(
            decoration: _inputDecoration("Phone Number", Icons.phone_outlined),
            style: const TextStyle(color: Colors.white),
            initialCountryCode: 'BD',
            dropdownTextStyle: const TextStyle(color: Colors.white),
            onChanged: (phone) {
              _phoneController.text = phone.completeNumber;
              _phoneValid = true;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("Password", Icons.lock_outline_rounded).copyWith(
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white38),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E8C)))
            : _actionButton("SIGN UP", _register),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOtpForm() {
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text(
          "Verify your email",
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Text(
          "We sent a 6-digit code to ${_emailController.text}. It expires in 5 minutes.",
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(fontSize: 14, color: Colors.white38),
        ),
        const SizedBox(height: 48),
        TextFormField(
          controller: _otpController,
          style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: _inputDecoration("Enter Code", Icons.security_rounded).copyWith(counterText: ""),
        ),
        const SizedBox(height: 32),
        _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E8C)))
          : _actionButton("VERIFY & LOGIN", _verifyAndComplete),
        const SizedBox(height: 16),
        if (!_isLoading)
          TextButton(
            onPressed: () => setState(() => _currentStep = RegisterStep.details),
            child: Text("Wrong email? Go back", style: GoogleFonts.outfit(color: Colors.white54)),
          ),
      ],
    );
  }

  Widget _cameraIcon() {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(color: const Color(0xFFE91E8C), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0D0D1A), width: 2)),
      child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFE91E8C), Color(0xFF9C27B0)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFFE91E8C).withValues(alpha: 0.35), blurRadius: 20)],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
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
