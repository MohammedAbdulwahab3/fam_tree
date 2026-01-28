import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

/// Phone verification dialog for SMS code input
class PhoneVerificationDialog extends ConsumerStatefulWidget {
  final String phoneNumber;

  const PhoneVerificationDialog({
    super.key,
    required this.phoneNumber,
  });

  @override
  ConsumerState<PhoneVerificationDialog> createState() =>
      _PhoneVerificationDialogState();
}

class _PhoneVerificationDialogState
    extends ConsumerState<PhoneVerificationDialog> {
  final _codeController = TextEditingController();
  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the 6-digit code'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final controller = ref.read(authControllerProvider.notifier);
    await controller.verifySMSCode(code);

    final state = ref.read(authControllerProvider);
    
    if (state.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error!),
          backgroundColor: AppTheme.error,
        ),
      );
    } else if (!state.isLoading && state.verificationId == null && mounted) {
      // Verification successful - redirect to dashboard
      Navigator.of(context).pop();
      context.go('/dashboard');
    }
  }

  void _resendCode() async {
    if (_resendCooldown > 0) return;

    final controller = ref.read(authControllerProvider.notifier);
    await controller.verifyPhoneNumber(widget.phoneNumber);

    // Start cooldown
    setState(() => _resendCooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _resendCooldown--;
        if (_resendCooldown == 0) {
          timer.cancel();
        }
      });
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code sent!'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        decoration: AppTheme.glassDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                boxShadow: AppTheme.shadowGlow,
              ),
              child: const Icon(
                Icons.sms,
                size: 40,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: AppTheme.spaceLg),
            
            // Title
            Text(
              'Verify Your Phone',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            
            const SizedBox(height: AppTheme.spaceSm),
            
            // Subtitle
            Text(
              'Enter the 6-digit code sent to',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              widget.phoneNumber,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryLight,
              ),
            ),
            
            const SizedBox(height: AppTheme.spaceLg),
            
            // Code Input
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: AppTheme.textMuted,
                ),
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spaceMd,
                ),
              ),
              onChanged: (value) {
                if (value.length == 6) {
                  _verifyCode();
                }
              },
            ),
            
            const SizedBox(height: AppTheme.spaceXl),
            
            // Verify Button
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  boxShadow: authState.isLoading ? [] : AppTheme.shadowGlow,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: authState.isLoading ? null : _verifyCode,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spaceMd,
                      ),
                      child: authState.isLoading
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
                          : Text(
                              'Verify',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: AppTheme.spaceMd),
            
            // Resend Code
            TextButton(
              onPressed: _resendCooldown > 0 ? null : _resendCode,
              child: Text(
                _resendCooldown > 0
                    ? 'Resend code in ${_resendCooldown}s'
                    : 'Resend code',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _resendCooldown > 0
                      ? AppTheme.textMuted
                      : AppTheme.primaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
