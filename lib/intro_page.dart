import 'package:flutter/material.dart';
import 'dart:async';

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeScale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeScale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _controller.forward();

    // pindah ke home setelah 2 detik
    Timer(const Duration(seconds: 2), () {
      Navigator.pushReplacementNamed(context, '/home');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F3D33), Color(0xFF1B6B5F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeScale,
            child: ScaleTransition(
              scale: _fadeScale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Aromind',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Find your perfect tropical vibe 🍃',
                    style: TextStyle(
                      color: cs.onPrimary.withOpacity(0.85),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
