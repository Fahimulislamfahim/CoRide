import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    const primaryColor = Color(0xFF0F5132); // DIU Green
    const accentColor = Color(0xFF00B4D8); // Sky Teal Accent
    const darkSlate = Color(0xFF1E293B);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Premium Linear Gradient Background with soft graphic elements
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE8F5E9), Color(0xFFE0F7FA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          // Decorative blur circles
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.08),
              ),
            ),
          ),

          // 2. Main Login Form Container
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Hero(
                  tag: 'auth_card',
                  child: Card(
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.04),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: Colors.white.withOpacity(0.6), width: 1.5),
                    ),
                    color: Colors.white.withOpacity(0.95),
                    child: Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // DIU Identity Header Icon
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.directions_car_filled_outlined, size: 36, color: primaryColor),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'CoRide',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Text(
                              'Campus Ridesharing & Carpooling',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 32),
                            
                            // Registration fields
                            if (!_isLoginMode) ...[
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: Icon(Icons.person_outline, size: 20, color: primaryColor),
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'Please enter your name' : null,
                                onSaved: (value) => _name = value!,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Student / Employee ID',
                                  prefixIcon: Icon(Icons.badge_outlined, size: 20, color: primaryColor),
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'Please enter your DIU ID' : null,
                                onSaved: (value) => _studentId = value!,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Phone Contact',
                                  prefixIcon: Icon(Icons.phone_android_outlined, size: 20, color: primaryColor),
                                ),
                                keyboardType: TextInputType.phone,
                                validator: (value) => value == null || value.length < 10 ? 'Please enter your phone number' : null,
                                onSaved: (value) => _phone = value!,
                              ),
                               const SizedBox(height: 16),
                            ],
                            
                            // Email Input
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'DIU Academic Email',
                                helperText: 'Must use official @diu.edu.bd domain',
                                helperStyle: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                prefixIcon: Icon(Icons.email_outlined, size: 20, color: primaryColor),
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
                            ),
                            const SizedBox(height: 16),
                            
                            // Password Input
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock_outline, size: 20, color: primaryColor),
                              ),
                              obscureText: true,
                              validator: (value) => value == null || value.length < 6 ? 'Password must be at least 6 characters' : null,
                              onSaved: (value) => _password = value!,
                            ),
                            const SizedBox(height: 20),
                            
                            // Segmented Role cards (Instead of boring Spinner)
                            if (!_isLoginMode) ...[
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: 8.0, left: 4),
                                  child: Text('Register as:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: darkSlate)),
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(child: _buildRoleCard('Passenger', Icons.people_outline)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildRoleCard('Rider', Icons.motorcycle_outlined)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildRoleCard('Both', Icons.commute_outlined)),
                                ],
                              ),
                              const SizedBox(height: 28),
                            ],
                            
                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: authProvider.isLoading ? null : _submitForm,
                                child: authProvider.isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : Text(
                                        _isLoginMode ? 'Login Session' : 'Create Account',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Form toggler link
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isLoginMode = !_isLoginMode;
                                });
                              },
                              child: Text(
                                _isLoginMode ? 'Don\'t have a commuter account? Sign Up' : 'Already registered? Login here',
                                style: const TextStyle(color: accentColor, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ],
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

  // Modern UI Card Button Selector for Roles
  Widget _buildRoleCard(String roleName, IconData icon) {
    final isSelected = _role == roleName;
    const primaryColor = Color(0xFF0F5132);

    return InkWell(
      onTap: () {
        setState(() {
          _role = roleName;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.08) : Colors.white,
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? primaryColor : Colors.grey.shade600, size: 22),
            const SizedBox(height: 6),
            Text(
              roleName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? primaryColor : Colors.grey.shade700,
              ),
            )
          ],
        ),
      ),
    );
  }
}
