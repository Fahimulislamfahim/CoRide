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
        SnackBar(content: Text(_isLoginMode ? 'Welcome back to CoRide!' : 'Registration successful!')),
      );
    } else if (authProvider.error != null && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Authentication Error'),
          content: Text(authProvider.error!),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    // Sleek Daffodil University Theme Colors
    const primaryColor = Color(0xFF0F5132); // DIU Green
    const accentColor = Color(0xFF0D6EFD); // Blue accent

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header logo / title
                      const Icon(Icons.directions_car_filled, size: 64, color: primaryColor),
                      const SizedBox(height: 12),
                      const Text(
                        'CoRide',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Text(
                        'DIU Smart City Ridesharing',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 28),
                      
                      // Registration specific fields
                      if (!_isLoginMode) ...[
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person, color: primaryColor),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'Please enter your name' : null,
                          onSaved: (value) => _name = value!,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Student / Employee ID',
                            prefixIcon: Icon(Icons.badge, color: primaryColor),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'Please enter your DIU ID' : null,
                          onSaved: (value) => _studentId = value!,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone, color: primaryColor),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) => value == null || value.length < 10 ? 'Please enter a valid phone number' : null,
                          onSaved: (value) => _phone = value!,
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Email Field (Enforces @diu.edu.bd)
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'DIU Academic Email',
                          helperText: 'Must end with @diu.edu.bd',
                          prefixIcon: Icon(Icons.email, color: primaryColor),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.endsWith('@diu.edu.bd')) {
                            return 'Must be an official DIU email domain';
                          }
                          return null;
                        },
                        onSaved: (value) => _email = value!.trim(),
                      ),
                      const SizedBox(height: 16),
                      
                      // Password Field
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock, color: primaryColor),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) => value == null || value.length < 6 ? 'Password must be at least 6 characters' : null,
                        onSaved: (value) => _password = value!,
                      ),
                      const SizedBox(height: 16),
                      
                      // Role Selector
                      if (!_isLoginMode) ...[
                        DropdownButtonFormField<String>(
                          value: _role,
                          decoration: const InputDecoration(
                            labelText: 'Registration Role',
                            prefixIcon: Icon(Icons.commute, color: primaryColor),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Passenger', child: Text('Passenger (Search Rides)')),
                            DropdownMenuItem(value: 'Rider', child: Text('Rider (Offer Rides)')),
                            DropdownMenuItem(value: 'Both', child: Text('Both (Offer & Search)')),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _role = val!;
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: authProvider.isLoading ? null : _submitForm,
                          child: authProvider.isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(_isLoginMode ? 'Login' : 'Register', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Mode Switcher
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLoginMode = !_isLoginMode;
                          });
                        },
                        child: Text(
                          _isLoginMode ? 'Don\'t have an account? Sign Up' : 'Already registered? Login',
                          style: const TextStyle(color: accentColor),
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
    );
  }
}
