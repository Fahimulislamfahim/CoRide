import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoginMode = true;
  String _email = '';
  String _password = '';
  String _name = '';
  String _studentId = '';
  String _phone = '';
  String _role = 'Passenger'; // Default role

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    _formKey.currentState!.save();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    bool success;
    if (_isLoginMode) {
      success = await authProvider.login(_email, _password);
    } else {
      success = await authProvider.register(
        name: _name,
        email: _email,
        password: _password,
        studentId: _studentId,
        phone: _phone,
        role: _role,
      );
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isLoginMode ? 'Welcome back to CoRide!' : 'Registration successful!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (authProvider.error != null && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Authentication Error'),
            ],
          ),
          content: Text(authProvider.error!),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }

  }

  // Modern UI Card Button Selector for Roles
  Widget _buildRoleCard(String roleName, IconData icon) {
    final isSelected = _role == roleName;
    const primaryColor = Color(0xFF101828);
    const accentColor = Color(0xFF2E90FA);

    return GestureDetector(
      onTap: () {
        setState(() {
          _role = roleName;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF8FF) : Colors.white,
          border: Border.all(
            color: isSelected ? accentColor : const Color(0xFFEAECF0),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected ? [
            BoxShadow(
              color: accentColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? accentColor : const Color(0xFF667085),
              size: 24
            ),
            const SizedBox(height: 8),
            Text(
              roleName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? accentColor : const Color(0xFF344054),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    const primaryColor = Color(0xFF101828); // Deep sleek charcoal
    const accentColor = Color(0xFF2E90FA); // Slick modern blue

    return Scaffold(
      body: Stack(
        children: [
          // 1. Premium Minimalist Background
          Container(
            color: const Color(0xFFF9FAFB),
            width: double.infinity,
            height: double.infinity,
          ),
          
          // Soft ambient mesh gradient shapes (modern UI trend)
          Positioned(
            top: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentColor.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true)).move(duration: 4000.ms, begin: const Offset(0, 0), end: const Offset(20, 20)),
          ),

          Positioned(
            bottom: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF027A48).withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true)).move(duration: 5000.ms, begin: const Offset(0, 0), end: const Offset(-20, -10)),
          ),

          // 2. Main Login Form Container
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Hero(
                  tag: 'auth_card',
                  child: Card(
                    // Card theme handled in main.dart is already premium
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Form(
                        key: _formKey,
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Identity Header
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F4F7),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFEAECF0)),
                                ),
                                child: const Icon(Icons.directions_car_filled_rounded, size: 36, color: primaryColor),
                              ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack),
                              const SizedBox(height: 24),

                              Text(
                                _isLoginMode ? 'Welcome back' : 'Create an account',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                  letterSpacing: -0.5,
                                ),
                              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

                              const SizedBox(height: 8),

                              Text(
                                _isLoginMode ? 'Enter your details to access CoRide.' : 'Join the campus ridesharing network.',
                                style: const TextStyle(fontSize: 15, color: Color(0xFF475467)),
                                textAlign: TextAlign.center,
                              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),

                              const SizedBox(height: 32),

                              // Registration fields
                              if (!_isLoginMode) ...[
                                TextFormField(
                                  decoration: const InputDecoration(
                                    labelText: 'Full Name',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (value) => value == null || value.isEmpty ? 'Please enter your name' : null,
                                  onSaved: (value) => _name = value!,
                                ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
                                const SizedBox(height: 16),

                                TextFormField(
                                  decoration: const InputDecoration(
                                    labelText: 'Student / Employee ID',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                  validator: (value) => value == null || value.isEmpty ? 'Please enter your DIU ID' : null,
                                  onSaved: (value) => _studentId = value!,
                                ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
                                const SizedBox(height: 16),

                                TextFormField(
                                  decoration: const InputDecoration(
                                    labelText: 'Phone Contact',
                                    prefixIcon: Icon(Icons.phone_android_outlined),
                                  ),
                                  keyboardType: TextInputType.phone,
                                  validator: (value) => value == null || value.length < 10 ? 'Please enter your phone number' : null,
                                  onSaved: (value) => _phone = value!,
                                ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
                                const SizedBox(height: 16),
                              ],

                              // Email Input
                              TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'DIU Academic Email',
                                  helperText: 'Must use official @diu.edu.bd domain',
                                  helperStyle: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  // Subtle highlight when registering to indicate domain rule
                                  filled: !_isLoginMode,
                                  fillColor: _isLoginMode ? Colors.white : const Color(0xFFF9FAFB),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!value.endsWith('@diu.edu.bd')) {
                                    return 'Use official @diu.edu.bd email domain';
                                  }
                                  return null;
                                },
                                onSaved: (value) => _email = value!.trim(),
                              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                              const SizedBox(height: 16),

                              // Password Input
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                                obscureText: true,
                                validator: (value) => value == null || value.length < 6 ? 'Password must be at least 6 characters' : null,
                                onSaved: (value) => _password = value!,
                              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
                              const SizedBox(height: 24),

                              // Segmented Role cards
                              if (!_isLoginMode) ...[
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: 12.0, left: 4),
                                    child: Text('Register account role:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF344054))),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Expanded(child: _buildRoleCard('Passenger', Icons.people_outline)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildRoleCard('Rider', Icons.motorcycle_outlined)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildRoleCard('Both', Icons.commute_outlined)),
                                  ],
                                ).animate().fadeIn(duration: 400.ms).scaleY(alignment: Alignment.topCenter),
                                const SizedBox(height: 32),
                              ],

                              // Submit Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: authProvider.isLoading ? null : _submitForm,
                                  child: authProvider.isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                        )
                                      : Text(
                                          _isLoginMode ? 'Sign in' : 'Create account',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                ),
                              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
                              const SizedBox(height: 24),

                              // Form toggler link
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isLoginMode = !_isLoginMode;
                                  });
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: accentColor,
                                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                child: Text(
                                  _isLoginMode ? 'Don\'t have an account? Sign up' : 'Already have an account? Log in',
                                ),
                              ).animate().fadeIn(delay: 700.ms),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
