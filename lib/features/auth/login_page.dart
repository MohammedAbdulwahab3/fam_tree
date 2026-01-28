import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';
import 'package:family_tree/features/auth/widgets/phone_verification_dialog.dart';
import 'package:google_fonts/google_fonts.dart';

/// Login page with multiple authentication options
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String _countryCode = '+251';
  bool _isSignUp = false;
  bool _showPhoneAuth = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _signInWithGoogle() async {
    final controller = ref.read(authControllerProvider.notifier);
    await controller.signInWithGoogle();

    final state = ref.read(authControllerProvider);
    if (state.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error!),
          backgroundColor: AppTheme.error,
        ),
      );
    } else if (mounted) {
      // Redirect to tree after sign in
      context.go('/tree');
    }
  }

  void _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final controller = ref.read(authControllerProvider.notifier);

    if (_isSignUp) {
      await controller.signUpWithEmail(email, password);
    } else {
      await controller.signInWithEmail(email, password);
    }

    final state = ref.read(authControllerProvider);
    if (state.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error!),
          backgroundColor: AppTheme.error,
        ),
      );
    } else if (mounted) {
      // Redirect to tree after sign in/up
      context.go('/tree');
    }
  }

  void _sendPhoneCode() async {
    if (!_formKey.currentState!.validate()) return;

    final phoneNumber = _countryCode + _phoneController.text.trim();
    final controller = ref.read(authControllerProvider.notifier);

    await controller.verifyPhoneNumber(phoneNumber);

    final state = ref.read(authControllerProvider);
    
    if (state.verificationId != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PhoneVerificationDialog(
          phoneNumber: phoneNumber,
        ),
      );
    } else if (state.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error!),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController(text: _emailController.text);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text(
          'Reset Password',
          style: GoogleFonts.playfairDisplay(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: GoogleFonts.inter(color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.email, color: AppTheme.primaryLight),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppTheme.textMuted),
            ),
          ),
          Consumer(
            builder: (context, ref, _) {
              final authState = ref.watch(authControllerProvider);
              return ElevatedButton(
                onPressed: authState.isLoading ? null : () async {
                  final email = emailController.text.trim();
                  if (email.isEmpty || !email.contains('@')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid email'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                    return;
                  }
                  
                  await ref.read(authControllerProvider.notifier).sendPasswordResetEmail(email);
                  
                  final state = ref.read(authControllerProvider);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          state.error ?? 'Password reset email sent! Check your inbox.',
                        ),
                        backgroundColor: state.error != null ? AppTheme.error : Colors.green,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                ),
                child: authState.isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Send Reset Link'),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.backgroundDark,
              AppTheme.primaryDeep.withValues(alpha: 0.3),
              AppTheme.accentTeal.withValues(alpha: 0.2),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                      onPressed: () => context.go('/'),
                    ),
                  ),
                  
                  const SizedBox(height: AppTheme.spaceLg),
                  
                  // Title
                  Text(
                    _showPhoneAuth 
                        ? 'Phone Sign In' 
                        : (_isSignUp ? 'Create Account' : 'Welcome Back'),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  
                  const SizedBox(height: AppTheme.spaceMd),
                  
                  Text(
                    _showPhoneAuth
                        ? 'Enter your phone number'
                        : (_isSignUp ? 'Sign up to get started' : 'Sign in to continue'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  
                  const SizedBox(height: AppTheme.spaceXl),
                  
                  // Login Form Card
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.all(AppTheme.spaceLg),
                    decoration: AppTheme.glassDecoration(),
                    child: _showPhoneAuth ? _buildPhoneForm(authState) : _buildEmailForm(authState),
                  ),
                  
                  const SizedBox(height: AppTheme.spaceMd),
                  
                  // Toggle auth method
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showPhoneAuth = !_showPhoneAuth;
                      });
                    },
                    child: Text(
                      _showPhoneAuth 
                          ? 'Use Email Instead' 
                          : 'Use Phone Instead',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.primaryLight,
                      ),
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

  Widget _buildEmailForm(dynamic authState) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email Input
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: GoogleFonts.inter(color: AppTheme.textSecondary),
              hintText: 'your@email.com',
              hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.email, color: AppTheme.primaryLight),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          
          const SizedBox(height: AppTheme.spaceMd),
          
          // Password Input
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: GoogleFonts.inter(color: AppTheme.textSecondary),
              hintText: '••••••••',
              hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.lock, color: AppTheme.primaryLight),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppTheme.textMuted,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (_isSignUp && value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          
          const SizedBox(height: AppTheme.spaceSm),
          
          // Remember Me and Forgot Password row
          if (!_isSignUp)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Remember Me
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (val) => setState(() => _rememberMe = val ?? true),
                      activeColor: AppTheme.primaryLight,
                      side: const BorderSide(color: AppTheme.textMuted),
                    ),
                    Text(
                      'Remember Me',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                // Forgot Password
                TextButton(
                  onPressed: () => _showForgotPasswordDialog(),
                  child: Text(
                    'Forgot Password?',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.primaryLight,
                    ),
                  ),
                ),
              ],
            ),
          
          const SizedBox(height: AppTheme.spaceMd),
          
          // Sign In/Up Button
          _buildGradientButton(
            onPressed: authState.isLoading ? null : _signInWithEmail,
            isLoading: authState.isLoading,
            label: _isSignUp ? 'Sign Up' : 'Sign In',
            icon: Icons.arrow_forward,
          ),
          
          const SizedBox(height: AppTheme.spaceMd),
          
          // Toggle Sign Up/In
          TextButton(
            onPressed: () {
              setState(() {
                _isSignUp = !_isSignUp;
              });
            },
            child: Text(
              _isSignUp 
                  ? 'Already have an account? Sign In' 
                  : 'Don\'t have an account? Sign Up',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          
          const SizedBox(height: AppTheme.spaceMd),
          
          // Divider
          Row(
            children: [
              const Expanded(child: Divider(color: AppTheme.textMuted)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
                child: Text(
                  'OR',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: AppTheme.textMuted)),
            ],
          ),
          
          const SizedBox(height: AppTheme.spaceMd),
          
          // Google Sign In Button
          OutlinedButton.icon(
            onPressed: authState.isLoading ? null : _signInWithGoogle,
            icon: const Icon(Icons.g_mobiledata, size: 28),
            label: const Text('Continue with Google'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              side: const BorderSide(color: AppTheme.textMuted),
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneForm(dynamic authState) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Country Code Selector
          DropdownButtonFormField<String>(
            value: _countryCode,
            decoration: InputDecoration(
              labelText: 'Country Code',
              labelStyle: GoogleFonts.inter(color: AppTheme.textSecondary),
              prefixIcon: const Icon(Icons.flag, color: AppTheme.primaryLight),
            ),
            dropdownColor: AppTheme.cardDark,
            items: const [
              DropdownMenuItem(value: '+251', child: Text('+251 (Ethiopia)')),
              DropdownMenuItem(value: '+1', child: Text('+1 (US/Canada)')),
              DropdownMenuItem(value: '+44', child: Text('+44 (UK)')),
              DropdownMenuItem(value: '+91', child: Text('+91 (India)')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _countryCode = value);
              }
            },
          ),
          
          const SizedBox(height: AppTheme.spaceMd),
          
          // Phone Number Input
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Phone Number',
              labelStyle: GoogleFonts.inter(color: AppTheme.textSecondary),
              hintText: '912345678',
              hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.phone, color: AppTheme.primaryLight),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your phone number';
              }
              if (value.length < 9) {
                return 'Phone number must be at least 9 digits';
              }
              return null;
            },
          ),
          
          const SizedBox(height: AppTheme.spaceXl),
          
          // Send Code Button
          _buildGradientButton(
            onPressed: authState.isLoading ? null : _sendPhoneCode,
            isLoading: authState.isLoading,
            label: 'Send Code',
            icon: Icons.send,
          ),
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    required VoidCallback? onPressed,
    required bool isLoading,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: isLoading ? [] : AppTheme.shadowGlow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceSm),
                      Icon(icon, color: Colors.white, size: 20),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
