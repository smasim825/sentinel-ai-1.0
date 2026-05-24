import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SosButton extends StatefulWidget {
  final VoidCallback onPressed;
  
  const SosButton({super.key, required this.onPressed});

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFE91E8C), Color(0xFFD81B60)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE91E8C).withValues(alpha: 0.5),
                blurRadius: 40,
                spreadRadius: 10,
              ),
              BoxShadow(
                color: const Color(0xFF9C27B0).withValues(alpha: 0.3),
                blurRadius: 60,
                spreadRadius: 20,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: Center(
              child: Text(
                "SOS",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  shadows: [
                    const Shadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
