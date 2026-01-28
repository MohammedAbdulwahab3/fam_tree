import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/providers/auth_provider_new.dart';

class AuthTestPage extends ConsumerStatefulWidget {
  const AuthTestPage({super.key});

  @override
  ConsumerState<AuthTestPage> createState() => _AuthTestPageState();
}

class _AuthTestPageState extends ConsumerState<AuthTestPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    final result = await ref.read(authControllerProvider).register(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
        );

    setState(() {
      _isLoading = false;
      _isSuccess = result['success'];
      _message = result['success'] 
          ? '✅ Registration successful!' 
          : '❌ ${result['error']}';
    });
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    final result = await ref.read(authControllerProvider).login(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

    setState(() {
      _isLoading = false;
      _isSuccess = result['success'];
      _message = result['success'] 
          ? '✅ Login successful!' 
          : '❌ ${result['error']}';
    });
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider).logout();
    setState(() {
      _message = '👋 Logged out';
      _isSuccess = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Auth Test Page',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryDeep,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.backgroundDark,
              AppTheme.primaryDeep.withValues(alpha: 0.2),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  Text(
                    '🧪 Test New Auth System',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Testing JWT authentication with Go backend',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // Auth State Display
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: authState.when(
                      data: (user) => Text(
                        user != null 
                            ? '🟢 Authenticated: ${user['email']}' 
                            : '🔴 Not authenticated',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: user != null ? AppTheme.success : AppTheme.textMuted,
                        ),
                      ),
                      loading: () => Text(
                        '⏳ Checking auth state...',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      error: (error, _) => Text(
                        '❌ Error: $error',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.error),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Name Input (for registration)
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: 'John Doe',
                      prefixIcon: const Icon(Icons.person, color: AppTheme.primaryLight),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Email Input
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'test@example.com',
                      prefixIcon: const Icon(Icons.email, color: AppTheme.primaryLight),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Password Input
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: '••••••••',
                      prefixIcon: const Icon(Icons.lock, color: AppTheme.primaryLight),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _register,
                          icon: const Icon(Icons.person_add),
                          label: const Text('Register'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentTeal,
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _login,
                          icon: const Icon(Icons.login),
                          label: const Text('Login'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryLight,
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Logout Button
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),

                  // Message Display
                  if (_message != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isSuccess 
                            ? AppTheme.success.withValues(alpha: 0.2) 
                            : AppTheme.error.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isSuccess ? AppTheme.success : AppTheme.error,
                        ),
                      ),
                      child: Text(
                        _message!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: _isSuccess ? AppTheme.success : AppTheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  // Loading Indicator
                  if (_isLoading) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],

                  const SizedBox(height: 24),

                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📋 Test Instructions:',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '1. Fill in Name, Email, and Password\n'
                          '2. Click "Register" to create account\n'
                          '3. Click "Login" to sign in\n'
                          '4. Watch the auth state change above\n'
                          '5. Click "Logout" to sign out',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
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
