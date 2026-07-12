import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  void _navigateToAuth() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.ease;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF101828); // Deep sleek charcoal
    const accentColor = Color(0xFF2E90FA); // Slick modern blue

    return Scaffold(
      backgroundColor: primaryColor,
      body: Stack(
        children: [
          // 1. Premium Full-screen Imagery with dark gradient overlay
          Positioned.fill(
            child: Stack(
              children: [
                Image.asset(
                  'assets/scenic_commute_view.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF101828), Color(0xFF1D2939)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                // Premium gradient overlays for text readability and slick look
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withOpacity(0.0),
                        primaryColor.withOpacity(0.3),
                        primaryColor.withOpacity(0.9),
                        primaryColor,
                      ],
                      stops: const [0.0, 0.4, 0.7, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 1000.ms, curve: Curves.easeOut),
          ),

          // 2. Top App Logo / Branding
          Positioned(
            top: 60,
            left: 24,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    // Glassmorphism effect
                    backgroundBlendMode: BlendMode.overlay,
                  ),
                  child: const Icon(Icons.directions_car_filled, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'CoRide',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ).animate().slideY(begin: -0.5, end: 0, duration: 600.ms, curve: Curves.easeOutBack).fadeIn(),
          ),

          // 3. Bottom Content Area (Text & Buttons)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Main Title
                  const Text(
                    'Elevate your\ndaily commute.',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -1,
                    ),
                  ).animate().slideY(begin: 0.2, end: 0, duration: 700.ms, delay: 200.ms, curve: Curves.easeOutCubic).fadeIn(),
                  const SizedBox(height: 20),

                  // Description
                  Text(
                    'Connect with verified campus drivers. Share the ride, split the cost, and reduce your carbon footprint in style.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.7),
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ).animate().slideY(begin: 0.2, end: 0, duration: 700.ms, delay: 400.ms, curve: Curves.easeOutCubic).fadeIn(),
                  const SizedBox(height: 48),

                  // Onboarding buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: primaryColor,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _navigateToAuth,
                            child: const Text('Get Started', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ).animate().slideY(begin: 0.5, end: 0, duration: 600.ms, delay: 600.ms, curve: Curves.easeOutBack).fadeIn(),
                      const SizedBox(width: 16),
                      Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: IconButton(
                          onPressed: _navigateToAuth,
                          icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                        ),
                      ).animate().slideY(begin: 0.5, end: 0, duration: 600.ms, delay: 700.ms, curve: Curves.easeOutBack).fadeIn(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
