import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SafetyGuideScreen extends StatelessWidget {
  const SafetyGuideScreen({super.key});

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
        title: Text('App Guide & Privacy',
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildSectionTitle('REQUIRED PERMISSIONS', Icons.lock_open),
            const SizedBox(height: 16),
            _buildPermissionItem(
              icon: Icons.location_on,
              title: 'Precise Location',
              description: 'Used to send your live coordinates to guardians during an SOS. We never track you unless an alert is active.',
              color: Colors.blue,
            ),
            _buildPermissionItem(
              icon: Icons.mic,
              title: 'Microphone Access',
              description: 'Required for our Voice AI to listen for your distress keywords ("Bachao", "Help") even when the phone is locked.',
              color: Colors.orange,
            ),
            _buildPermissionItem(
              icon: Icons.phone,
              title: 'Phone & SMS',
              description: 'Allows the app to automatically call your emergency contacts and send SMS alerts with your location.',
              color: Colors.green,
            ),
            _buildPermissionItem(
              icon: Icons.vibration,
              title: 'Sensors & Activity',
              description: 'Used to detect emergency shake gestures or fall detection via the phone or connected wristband.',
              color: Colors.purple,
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('HOW SENTINEL WORKS', Icons.info_outline),
            const SizedBox(height: 16),
            _buildFeatureStep(
              step: '1',
              title: 'Add Guardians',
              desc: 'Go to your Profile and add trusted friends or family members as guardians.',
            ),
            _buildFeatureStep(
              step: '2',
              title: 'Background Protection',
              desc: 'Sentinel runs in the background. If you shout "Bachao", the app detects it instantly.',
            ),
            _buildFeatureStep(
              step: '3',
              title: 'Auto-SOS Trigger',
              desc: 'When a threat is detected (Voice + Heart Rate Spike), Sentinel calls your guardians and shares your live location map.',
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('TERMS & CONDITIONS', Icons.description_outlined),
            const SizedBox(height: 16),
            _buildTermsCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF00BCD4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.security, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Transparency First',
                    style: GoogleFonts.outfit(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('We only use your data when your life is in danger.',
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6C63FF), size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.outfit(
                color: Colors.white38,
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1526),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.outfit(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(description,
                    style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureStep({required String step, required String title, required String desc}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFF6C63FF),
            child: Text(step,
                style: GoogleFonts.outfit(
                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.outfit(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(desc,
                    style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1526),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text(
        '1. Data Privacy: Your biometric data and location are never stored on our servers. All processing happens on-device.\n\n'
        '2. Emergency Use: Sentinel is a safety tool. False alarms should be cleared immediately using the "Deactivate" button.\n\n'
        '3. Liability: While Sentinel aim to maximize safety, it is a tool to assist, not a substitute for professional law enforcement.',
        style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11, height: 1.8),
      ),
    );
  }
}
