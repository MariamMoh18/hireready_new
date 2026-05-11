import 'package:flutter/material.dart';
import 'package:ai_interview/config/app_icons.dart';
import 'package:ai_interview/config/app_routes.dart';
import 'package:ai_interview/services/auth_service.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Validation state
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  bool _submitted = false;

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
    _emailController.addListener(_onEmailChanged);
    _passwordController.addListener(_onPasswordChanged);
    _confirmPasswordController.addListener(_onConfirmPasswordChanged);
    _nameFocus.addListener(_onNameFocusChanged);
    _emailFocus.addListener(_onEmailFocusChanged);
    _passwordFocus.addListener(_onPasswordFocusChanged);
    _confirmPasswordFocus.addListener(_onConfirmPasswordFocusChanged);
  }

  void _onNameChanged() {
    final err = _validateNameOnly(_nameController.text);
    if (err != _nameError) setState(() => _nameError = err);
  }

  void _onEmailChanged() {
    final err = _validateEmailOnly(_emailController.text);
    if (err != _emailError) setState(() => _emailError = err);
  }

  void _onPasswordChanged() {
    final err = _validatePasswordOnly(_passwordController.text);
    if (err != _passwordError) setState(() => _passwordError = err);
    // Re-validate confirm password if it has content
    if (_confirmPasswordController.text.isNotEmpty) {
      final confirmErr = _validateConfirmPasswordOnly(
        _confirmPasswordController.text, _passwordController.text);
      if (confirmErr != _confirmPasswordError) {
        setState(() => _confirmPasswordError = confirmErr);
      }
    }
  }

  void _onConfirmPasswordChanged() {
    final err = _validateConfirmPasswordOnly(
      _confirmPasswordController.text, _passwordController.text);
    if (err != _confirmPasswordError) setState(() => _confirmPasswordError = err);
  }

  void _onNameFocusChanged() {
    if (!_nameFocus.hasFocus && _nameError != null) {
      setState(() => _nameError = _validateNameOnly(_nameController.text));
    }
  }

  void _onEmailFocusChanged() {
    if (!_emailFocus.hasFocus && _emailError != null) {
      setState(() => _emailError = _validateEmailOnly(_emailController.text));
    }
  }

  void _onPasswordFocusChanged() {
    if (!_passwordFocus.hasFocus && _passwordError != null) {
      setState(() => _passwordError = _validatePasswordOnly(_passwordController.text));
    }
  }

  void _onConfirmPasswordFocusChanged() {
    if (!_confirmPasswordFocus.hasFocus && _confirmPasswordError != null) {
      setState(() => _confirmPasswordError = _validateConfirmPasswordOnly(
        _confirmPasswordController.text, _passwordController.text));
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _emailController.removeListener(_onEmailChanged);
    _passwordController.removeListener(_onPasswordChanged);
    _confirmPasswordController.removeListener(_onConfirmPasswordChanged);
    _nameFocus.removeListener(_onNameFocusChanged);
    _emailFocus.removeListener(_onEmailFocusChanged);
    _passwordFocus.removeListener(_onPasswordFocusChanged);
    _confirmPasswordFocus.removeListener(_onConfirmPasswordFocusChanged);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  // ── Validation methods ──────────────────────────────────────────

  String? _validateNameOnly(String value) {
    if (!_submitted) return null;
    final name = value.trim();
    if (name.isEmpty) return 'Username is required';
    if (name.length < 3) return 'Username must be at least 3 characters';
    if (name.length > 20) return 'Username cannot exceed 20 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(name)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  String? _validateEmailOnly(String value) {
    if (!_submitted) return null;
    final email = value.trim();
    if (email.isEmpty) return 'Email is required';
    if (email.contains(' ')) return 'Email cannot contain spaces';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePasswordOnly(String value) {
    if (!_submitted) return null;
    if (value.isEmpty) return 'Password is required';
    if (value.length <= 6) return 'Password must be more than 6 characters';
    return null;
  }

  String? _validateConfirmPasswordOnly(String value, String password) {
    if (!_submitted) return null;
    if (value.isEmpty) return 'Please confirm your password';
    if (value != password) return 'Passwords do not match';
    return null;
  }

  bool _validateAll() {
    _submitted = true;
    final nameErr = _validateNameOnly(_nameController.text);
    final emailErr = _validateEmailOnly(_emailController.text);
    final passwordErr = _validatePasswordOnly(_passwordController.text);
    final confirmErr = _validateConfirmPasswordOnly(
      _confirmPasswordController.text, _passwordController.text);
    setState(() {
      _nameError = nameErr;
      _emailError = emailErr;
      _passwordError = passwordErr;
      _confirmPasswordError = confirmErr;
    });
    return nameErr == null && emailErr == null &&
           passwordErr == null && confirmErr == null;
  }

  InputDecoration _buildDecoration({
    required String hintText,
    required Widget? prefixIcon,
    Widget? suffixIcon,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      errorText: errorText,
      errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
      errorMaxLines: 2,
      filled: true,
      fillColor: Colors.grey[200],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 18,
      ),
    );
  }

  Future<void> _handleSignUp() async {
    // Frontend validation first — do NOT call API if invalid
    if (!_validateAll()) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);

    final result = await AuthService.register(
      name: name,
      email: email,
      password: password,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success'] == true) {
      // Auto-login after successful registration to get JWT token
      final loginResult = await AuthService.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (loginResult['success'] == true) {
        if (loginResult['profile_completed'] == true) {
          Navigator.of(context).pushReplacementNamed(
            AppRoutes.home,
          );
        } else {
          Navigator.of(context).pushReplacementNamed(
            AppRoutes.profileSetup,
            arguments: {'name': name},
          );
        }
      } else {
        // Fallback to login page if auto-login fails
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.login,
          arguments: {'registrationSuccess': true},
        );
      }
    } else {
      // Map backend errors to field-level validation
      final message = result['message'] ?? '';
      if (message.toLowerCase().contains('email already exists') ||
          message.toLowerCase().contains('already exists')) {
        setState(() => _emailError = 'This email is already in use');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 32.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // App Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E83FF),
                    image: DecorationImage(
                      image: AssetImage(AppIcons.icAilogin),
                      fit: BoxFit.cover,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 32),
                // Create your Profile Title
                const Text(
                  'Create your Profile',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    height: 1.38,
                  ),
                ),
                const SizedBox(height: 48),
                // Name Field
                TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  keyboardType: TextInputType.name,
                  style: const TextStyle(color: Colors.black),
                  decoration: _buildDecoration(
                    hintText: 'Full Name',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Icon(Icons.person_outline,
                          color: Colors.grey, size: 20),
                    ),
                    errorText: _nameError,
                  ),
                ),
                const SizedBox(height: 20),
                // Email Field
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.black),
                  decoration: _buildDecoration(
                    hintText: 'Email',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SvgPicture.asset(
                        AppIcons.email,
                        height: 20,
                        width: 20,
                        colorFilter: const ColorFilter.mode(
                          Colors.grey,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    errorText: _emailError,
                  ),
                ),
                const SizedBox(height: 20),
                // Password Field
                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.black),
                  decoration: _buildDecoration(
                    hintText: 'Password',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SvgPicture.asset(
                        AppIcons.lock,
                        height: 20,
                        width: 20,
                        colorFilter: const ColorFilter.mode(
                          Colors.grey,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    errorText: _passwordError,
                  ),
                ),
                const SizedBox(height: 20),
                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  focusNode: _confirmPasswordFocus,
                  obscureText: _obscureConfirmPassword,
                  style: const TextStyle(color: Colors.black),
                  decoration: _buildDecoration(
                    hintText: 'Confirm Password',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SvgPicture.asset(
                        AppIcons.lock,
                        height: 20,
                        width: 20,
                        colorFilter: const ColorFilter.mode(
                          Colors.grey,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    errorText: _confirmPasswordError,
                  ),
                ),
                const SizedBox(height: 32),
                // Continue Button with Gradient
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E83FF), Color(0xFF0066CC)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
                // Divider Text
                const Text(
                  'or continue with',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 24),
                // Google Sign-up Button
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      // Handle Google sign-up
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(AppIcons.icGoogle, height: 24, width: 24),
                        const SizedBox(width: 12),
                        const Text(
                          'Sign up with Google',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Facebook Sign-up Button
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      // Handle Facebook sign-up
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(AppIcons.icFacebook, height: 24, width: 24),
                        const SizedBox(width: 12),
                        const Text(
                          'Sign up with Facebook',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Log In Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'already have an account?',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushReplacementNamed(AppRoutes.login);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.only(left: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'log in',
                        style: TextStyle(
                          color: Color(0xFF1E83FF),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
