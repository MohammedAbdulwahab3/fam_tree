import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/app_colors.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/core/widgets/aurora_background.dart';
import 'package:family_tree/core/widgets/tree_mark.dart';
import 'package:family_tree/data/services/auth_service.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';

/// Email + password sign in against the Go backend.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AnimationController _auroraController;
  late final AnimationController _entryController;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Slow drift behind the glass — long enough that it reads as ambient
    // light rather than motion competing with the form.
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entryFade = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(_entryFade);
    _entryController.forward();
  }

  @override
  void dispose() {
    _auroraController.dispose();
    _entryController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(authControllerProvider.notifier);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final isNewAccount = _isSignUp;
    if (isNewAccount) {
      await controller.signUpWithEmail(email, password,
          name: _nameController.text);
    } else {
      await controller.signInWithEmail(email, password);
    }

    if (!mounted) return;

    final error = ref.read(authControllerProvider).error;
    if (error != null) {
      _showError(error);
      return;
    }

    // A brand new account lands on the tree with no idea that it is read-only
    // until they claim their own record, so say so once, right here, instead of
    // leaving it buried in the profile drawer.
    context.go(isNewAccount ? '/tree?welcome=1' : '/tree');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.all(16),
          content: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF7F1D1D),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Enter your password';
    // Matches the backend's `min=6` binding rule on /register.
    if (_isSignUp && password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: Stack(
        children: [
          AuroraBackground(animation: _auroraController, isDark: isDark),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 940;
                return FadeTransition(
                  opacity: _entryFade,
                  child: SlideTransition(
                    position: _entrySlide,
                    child: isWide
                        ? _buildSplitLayout(isDark, authState.isLoading)
                        : _buildStackedLayout(isDark, authState.isLoading),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: _GlassIconButton(
              icon: Icons.arrow_back_rounded,
              isDark: isDark,
              tooltip: 'Back to home',
              onTap: () => context.go('/'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitLayout(bool isDark, bool isBusy) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 660),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceXl),
          child: Row(
            children: [
              Expanded(flex: 5, child: _BrandPanel(isDark: isDark)),
              const SizedBox(width: AppTheme.space2xl),
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  child: _buildCard(isDark, isBusy),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStackedLayout(bool isDark, bool isBusy) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceLg,
          vertical: AppTheme.spaceXl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TreeMark(isDark: isDark, size: 64),
              const SizedBox(height: AppTheme.spaceLg),
              _GradientTitle(
                text: 'Mammedu Family',
                fontSize: 34,
                isDark: isDark,
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                'Every name, every branch, one story.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : ElegantColors.warmGray,
                ),
              ),
              const SizedBox(height: AppTheme.spaceXl),
              _buildCard(isDark, isBusy),
            ],
          ),
        ),
      ),
    );
  }

  /// The frosted form panel.
  Widget _buildCard(bool isDark, bool isBusy) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceXl),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.10),
                      Colors.white.withValues(alpha: 0.04),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.88),
                      Colors.white.withValues(alpha: 0.66),
                    ],
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.9),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isSignUp ? 'Create your account' : 'Welcome back',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: context.colors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isSignUp
                      ? 'Join the family tree in a moment.'
                      : 'Sign in to continue to your family tree.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark
                        ? AppTheme.textMutedDark
                        : ElegantColors.warmGray,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXl),

                // Name only exists on sign-up — animate it in rather than
                // letting the card jump height.
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: _isSignUp
                      ? Column(
                          children: [
                            _GlassField(
                              controller: _nameController,
                              label: 'Name',
                              icon: Icons.person_outline_rounded,
                              isDark: isDark,
                              textInputAction: TextInputAction.next,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Enter your name'
                                      : null,
                            ),
                            const SizedBox(height: AppTheme.spaceMd),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),

                _GlassField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.alternate_email_rounded,
                  isDark: isDark,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                ),
                const SizedBox(height: AppTheme.spaceMd),
                _GlassField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline_rounded,
                  isDark: isDark,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => isBusy ? null : _submit(),
                  validator: _validatePassword,
                  suffix: IconButton(
                    splashRadius: 20,
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: isDark
                          ? AppTheme.textMutedDark
                          : ElegantColors.warmGray,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                if (!_isSignUp) ...[
                  const SizedBox(height: AppTheme.spaceSm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: isBusy
                          ? null
                          : () => context.push('/reset-password'),
                      child: Text(
                        'Forgot your password?',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.primaryLight
                              : AppTheme.primaryDeep,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.spaceXl),
                _GradientButton(
                  label: _isSignUp ? 'Create account' : 'Sign in',
                  isBusy: isBusy,
                  onTap: isBusy ? null : _submit,
                ),
                const SizedBox(height: AppTheme.spaceLg),
                _buildToggle(isDark, isBusy),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggle(bool isDark, bool isBusy) {
    // Wrap, not Row: at small widths (or a large system text scale) these two
    // labels do not fit on one line and would otherwise overflow.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Text(
          _isSignUp ? 'Already have an account?' : "Don't have an account?",
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: context.colors.inkMuted,
          ),
        ),
        GestureDetector(
          onTap: isBusy
              ? null
              : () {
                  ref.read(authControllerProvider.notifier).clearError();
                  _formKey.currentState?.reset();
                  setState(() => _isSignUp = !_isSignUp);
                },
          child: Text(
            _isSignUp ? 'Sign in' : 'Create one',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: context.colors.accent,
            ),
          ),
        ),
      ],
    );
  }
}


/// Wide-screen brand column: mark, title, tagline, and a few reassurances.
class _BrandPanel extends StatelessWidget {
  final bool isDark;
  const _BrandPanel({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TreeMark(isDark: isDark, size: 76),
        const SizedBox(height: AppTheme.spaceLg),
        _GradientTitle(
          text: 'Mammedu\nFamily',
          fontSize: 60,
          isDark: isDark,
          align: TextAlign.left,
        ),
        const SizedBox(height: AppTheme.spaceMd),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(
            'Every name, every branch, one story — six generations kept together in one place.',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 21,
              height: 1.5,
              fontStyle: FontStyle.italic,
              color:
                  context.colors.inkSoft,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space2xl),
        _note(context, Icons.account_tree_outlined, '205 relatives across 6 generations'),
        const SizedBox(height: AppTheme.spaceMd),
        _note(context, Icons.translate_rounded, 'Names in English and አማርኛ'),
      ],
    );
  }

  Widget _note(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.accentTeal.withValues(alpha: isDark ? 0.18 : 0.14),
          ),
          child: Icon(icon, size: 17, color: AppTheme.accentTeal),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: context.colors.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// Gradient-filled display heading, matching the landing page treatment.
class _GradientTitle extends StatelessWidget {
  final String text;
  final double fontSize;
  final bool isDark;
  final TextAlign align;

  const _GradientTitle({
    required this.text,
    required this.fontSize,
    required this.isDark,
    this.align = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: isDark
            ? const [
                AppTheme.primaryLight,
                AppTheme.accentTeal,
                AppTheme.accentCyan,
              ]
            : const [
                AppTheme.primaryDeep,
                AppTheme.accentTeal,
                AppTheme.primaryLight,
              ],
      ).createShader(bounds),
      child: Text(
        text,
        textAlign: align,
        style: GoogleFonts.playfairDisplay(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          height: 1.05,
          letterSpacing: -1.5,
          color: Colors.white,
        ),
      ),
    );
  }
}



/// Text field styled for the frosted card, with a teal focus glow.
class _GlassField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isDark;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final TextCapitalization textCapitalization;

  const _GlassField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.isDark,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
    this.suffix,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<_GlassField> createState() => _GlassFieldState();
}

class _GlassFieldState extends State<_GlassField> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
      () => setState(() => _focused = _focusNode.hasFocus),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final idleBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : ElegantColors.warmGray.withValues(alpha: 0.22);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AppTheme.accentTeal.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : const [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onFieldSubmitted,
        validator: widget.validator,
        style: GoogleFonts.inter(
          fontSize: 15,
          color: context.colors.ink,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: GoogleFonts.inter(
            fontSize: 14,
            color: _focused
                ? AppTheme.accentTeal
                : (context.colors.inkMuted),
          ),
          prefixIcon: Icon(
            widget.icon,
            size: 20,
            color: _focused
                ? AppTheme.accentTeal
                : (context.colors.inkMuted),
          ),
          suffixIcon: widget.suffix,
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.75),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: _border(idleBorder),
          enabledBorder: _border(idleBorder),
          focusedBorder: _border(AppTheme.accentTeal, width: 1.6),
          errorBorder: _border(AppTheme.error),
          focusedErrorBorder: _border(AppTheme.error, width: 1.6),
          errorStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.error),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// Primary call to action: emerald→teal gradient with a lift on hover.
class _GradientButton extends StatefulWidget {
  final String label;
  final bool isBusy;
  final VoidCallback? onTap;

  const _GradientButton({
    required this.label,
    required this.isBusy,
    required this.onTap,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: 54,
        transform: Matrix4.translationValues(0, _hovered && enabled ? -2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          gradient: const LinearGradient(
            colors: [AppTheme.primaryDeep, AppTheme.accentTeal],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentTeal
                  .withValues(alpha: _hovered && enabled ? 0.45 : 0.28),
              blurRadius: _hovered && enabled ? 26 : 16,
              offset: Offset(0, _hovered && enabled ? 12 : 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Center(
              child: widget.isBusy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted circular icon button used for the back control.
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final String tooltip;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.isDark,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Tooltip(
        message: tooltip,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.7),
              child: InkWell(
                onTap: onTap,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    icon,
                    size: 20,
                    color: context.colors.ink,
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


/// Set a new password using a code from a family admin.
///
/// This deployment has no mail server, so there is no "reset link in your
/// inbox". An admin issues a one-time code and passes it on the way they would
/// normally reach that relative. Before this existed, forgetting your password
/// meant losing the account outright — there was no reset of any kind.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AnimationController _auroraController;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _auroraController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await AuthService().resetPasswordWithCode(
        email: _emailController.text,
        code: _codeController.text,
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      // Signed in already, so go straight where a sign-in would have gone.
      context.go('/tree');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is AuthException ? e.message : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          AuroraBackground(animation: _auroraController, isDark: isDark),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spaceXl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Set a new password',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: context.colors.ink,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceSm),
                        Text(
                          'Ask a family admin for a reset code, then enter it '
                          'here with your new password.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.45,
                            color: isDark
                                ? AppTheme.textMutedDark
                                : ElegantColors.warmGray,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceXl),
                        _GlassField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          isDark: isDark,
                          validator: (value) {
                            final email = (value ?? '').trim();
                            if (email.isEmpty) return 'Enter your email';
                            if (!email.contains('@') || !email.contains('.')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppTheme.spaceMd),
                        _GlassField(
                          controller: _codeController,
                          label: 'Reset code',
                          icon: Icons.vpn_key_outlined,
                          textCapitalization: TextCapitalization.characters,
                          isDark: isDark,
                          validator: (value) =>
                              (value ?? '').trim().isEmpty
                                  ? 'Enter the code the admin gave you'
                                  : null,
                        ),
                        const SizedBox(height: AppTheme.spaceMd),
                        _GlassField(
                          controller: _passwordController,
                          label: 'New password',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscure,
                          isDark: isDark,
                          validator: (value) {
                            final password = value ?? '';
                            if (password.isEmpty) return 'Choose a new password';
                            if (password.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                          suffix: IconButton(
                            splashRadius: 20,
                            tooltip:
                                _obscure ? 'Show password' : 'Hide password',
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: isDark
                                  ? AppTheme.textMutedDark
                                  : ElegantColors.warmGray,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: AppTheme.spaceMd),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.error.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded,
                                    size: 18, color: AppTheme.error),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: AppTheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: AppTheme.spaceXl),
                        _GradientButton(
                          label: 'Set password and sign in',
                          isBusy: _busy,
                          onTap: _busy ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: _GlassIconButton(
              icon: Icons.arrow_back_rounded,
              isDark: isDark,
              tooltip: 'Back to sign in',
              onTap: () => context.canPop() ? context.pop() : context.go('/login'),
            ),
          ),
        ],
      ),
    );
  }
}
