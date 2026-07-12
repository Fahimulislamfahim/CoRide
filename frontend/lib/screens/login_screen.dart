import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../main.dart'; // import ios colors

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
  String _selectedRole = 'Passenger';

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    bool success = false;
    if (_isLoginMode) {
      success = await authProvider.login(_email, _password);
    } else {
      success = await authProvider.register(
        name: _name,
        email: _email,
        password: _password,
        studentId: _studentId,
        phone: _phone,
        role: _selectedRole,
      );
    }

    if (!success && mounted) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text(authProvider.error ?? 'Authentication failed.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(ctx).pop(),
            )
          ],
        ),
      );
    }
  }

  Widget _buildRoleSegment() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: iosDarkGray,
        borderRadius: BorderRadius.circular(10),
      ),
      child: CupertinoSlidingSegmentedControl<String>(
        backgroundColor: CupertinoColors.transparent,
        thumbColor: iosWhite.withOpacity(0.15),
        groupValue: _selectedRole,
        children: const {
          'Passenger': Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('Passenger', style: TextStyle(color: iosTextLight))),
          'Rider': Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('Rider', style: TextStyle(color: iosTextLight))),
          'Both': Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('Both', style: TextStyle(color: iosTextLight))),
        },
        onValueChanged: (value) {
          if (value != null) {
            setState(() => _selectedRole = value);
          }
        },
      ),
    );
  }

  Widget _buildTextField({
    required String placeholder,
    required IconData prefixIcon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    required String? Function(String?) validator,
    required void Function(String?) onSaved,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: CupertinoTextFormFieldRow(
        placeholder: placeholder,
        placeholderStyle: const TextStyle(color: iosGrayText),
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: iosTextLight),
        decoration: BoxDecoration(
          color: iosDarkGray,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        prefix: Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: Icon(prefixIcon, color: iosGrayText, size: 20),
        ),
        validator: validator,
        onSaved: onSaved,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return CupertinoPageScaffold(
      backgroundColor: iosBlack,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon / Logo
                  Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(bottom: 32),
                    decoration: BoxDecoration(
                      color: iosBlue,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: iosBlue.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: const Icon(CupertinoIcons.car_detailed, size: 40, color: iosWhite),
                  ).animate().scale(curve: Curves.easeOutBack, duration: 600.ms),

                  Text(
                    _isLoginMode ? 'Sign In' : 'Create Account',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: iosTextLight,
                      letterSpacing: -1,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, duration: 400.ms),

                  const SizedBox(height: 8),

                  Text(
                    'Campus ridesharing, reimagined.',
                    style: TextStyle(
                      fontSize: 16,
                      color: iosTextLight.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 48),

                  // Fields Container
                  Container(
                    decoration: BoxDecoration(
                      color: iosDarkGray.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: [
                        if (!_isLoginMode) ...[
                          _buildTextField(
                            placeholder: 'Full Name',
                            prefixIcon: CupertinoIcons.person,
                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            onSaved: (val) => _name = val!,
                          ).animate().fadeIn().slideY(begin: -0.1),
                          _buildTextField(
                            placeholder: 'Student/Employee ID',
                            prefixIcon: CupertinoIcons.badge_plus_radiowaves_right,
                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            onSaved: (val) => _studentId = val!,
                          ).animate().fadeIn().slideY(begin: -0.1),
                          _buildTextField(
                            placeholder: 'Phone Number',
                            prefixIcon: CupertinoIcons.phone,
                            keyboardType: TextInputType.phone,
                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            onSaved: (val) => _phone = val!,
                          ).animate().fadeIn().slideY(begin: -0.1),
                        ],

                        _buildTextField(
                          placeholder: 'DIU Academic Email',
                          prefixIcon: CupertinoIcons.mail,
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Required';
                            if (!val.endsWith('@diu.edu.bd')) return 'Must be @diu.edu.bd';
                            return null;
                          },
                          onSaved: (val) => _email = val!.trim(),
                        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),

                        _buildTextField(
                          placeholder: 'Password',
                          prefixIcon: CupertinoIcons.lock,
                          obscureText: true,
                          validator: (val) => val == null || val.length < 6 ? 'Min 6 chars' : null,
                          onSaved: (val) => _password = val!,
                        ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),

                        if (!_isLoginMode) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Role', style: TextStyle(color: iosTextLight.withOpacity(0.6), fontSize: 13)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: _buildRoleSegment(),
                          ).animate().fadeIn().scale(alignment: Alignment.center),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  CupertinoButton(
                    color: iosBlue,
                    borderRadius: BorderRadius.circular(16),
                    onPressed: authProvider.isLoading ? null : _submitForm,
                    child: authProvider.isLoading
                        ? const CupertinoActivityIndicator(color: iosWhite)
                        : Text(
                            _isLoginMode ? 'Sign In' : 'Sign Up',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: iosWhite),
                          ),
                  ).animate().fadeIn(delay: 600.ms).scale(),

                  const SizedBox(height: 24),

                  CupertinoButton(
                    onPressed: () => setState(() => _isLoginMode = !_isLoginMode),
                    child: Text(
                      _isLoginMode ? "Don't have an account? Sign up" : 'Already have an account? Log in',
                      style: const TextStyle(color: iosBlue, fontSize: 15),
                    ),
                  ).animate().fadeIn(delay: 700.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
