import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:family_tree/core/design/design.dart';
import 'package:family_tree/core/widgets/tree_mark.dart';
import 'package:family_tree/features/auth/session.dart';

/// Signing in, and creating an account.
///
/// One screen with two modes rather than two screens, because the commonest
/// confusion for somebody new is not knowing which of the two they need. The
/// switch between them is a full-width row at the bottom, worded as a
/// question — "New to the app? Create an account" — rather than a tab.
///
/// Everything else follows from the reader: one field per line, labels above
/// the boxes, a password that can be shown, and errors that name what to do
/// rather than what went wrong.
class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key, this.startOnSignUp = false});

  final bool startOnSignUp;

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  late bool _creatingAccount = widget.startOnSignUp;
  bool _showPassword = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() {
      _creatingAccount = !_creatingAccount;
      _showPassword = false;
    });
    ref.read(sessionProvider.notifier).clearError();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final controller = ref.read(sessionProvider.notifier);
    final ok = _creatingAccount
        ? await controller.signUp(
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
          )
        : await controller.signIn(
            email: _email.text.trim(),
            password: _password.text,
          );

    if (!mounted || !ok) return;

    // A brand new account has nobody in the tree yet, so it goes straight to
    // the step that matters: finding yourself in the family.
    context.go(_creatingAccount ? '/welcome' : '/tree');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = ref.watch(sessionProvider);

    // A message explaining why they are looking at this screen, when they did
    // not choose to be.
    final signedOutNotice = switch (session.reason) {
      SignedOutReason.sessionExpired => (
          'You were signed out',
          'It has been a while since you last opened the app. Sign in again '
              'and everything will be where you left it.',
          NoticeTone.info,
        ),
      SignedOutReason.suspended => (
          'This account is suspended',
          session.error ??
              'An admin has suspended this account. Ask them to restore it.',
          NoticeTone.danger,
        ),
      SignedOutReason.accountGone => (
          'This account no longer exists',
          'It may have been removed. You can create a new one below.',
          NoticeTone.warning,
        ),
      SignedOutReason.none => null,
    };

    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.gutter,
              vertical: Insets.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Sizes.formWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TreeMark(size: 64),
                    const SizedBox(height: Insets.lg),
                    Text(
                      _creatingAccount ? 'Create your account' : 'Welcome back',
                      style: AppType.title.copyWith(color: c.ink),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      _creatingAccount
                          ? 'One account for the whole family tree. You only '
                              'need to do this once.'
                          : 'Sign in to see your family.',
                      style: AppType.body.copyWith(color: c.inkSoft),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Insets.lg),

                    if (signedOutNotice != null) ...[
                      AppNotice(
                        title: signedOutNotice.$1,
                        message: signedOutNotice.$2,
                        tone: signedOutNotice.$3,
                      ),
                      const SizedBox(height: Insets.md),
                    ],

                    if (_creatingAccount) ...[
                      AppTextField(
                        label: 'Your name',
                        controller: _name,
                        hint: 'Sara Tesfaye',
                        helper: 'The name your family will see.',
                        icon: Icons.person_outline_rounded,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        autofocus: true,
                        validator: _validateName,
                        onSubmitted: (_) => _emailFocus.requestFocus(),
                      ),
                      const SizedBox(height: Insets.md),
                    ],

                    AppTextField(
                      label: 'Email',
                      controller: _email,
                      focusNode: _emailFocus,
                      hint: 'you@example.com',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.none,
                      autofocus: !_creatingAccount,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      ],
                      validator: _validateEmail,
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                    ),
                    const SizedBox(height: Insets.md),

                    AppTextField(
                      label: 'Password',
                      controller: _password,
                      focusNode: _passwordFocus,
                      icon: Icons.lock_outline_rounded,
                      obscureText: !_showPassword,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.none,
                      helper: _creatingAccount
                          ? 'At least 6 characters. Something you will '
                              'remember.'
                          : null,
                      validator: _validatePassword,
                      onSubmitted: (_) => _submit(),
                      suffix: IconButton(
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                        tooltip: _showPassword
                            ? 'Hide password'
                            : 'Show password',
                      ),
                    ),

                    if (session.error != null &&
                        session.reason == SignedOutReason.none) ...[
                      const SizedBox(height: Insets.md),
                      AppNotice(
                        message: session.error!,
                        tone: NoticeTone.danger,
                      ),
                    ],

                    const SizedBox(height: Insets.lg),
                    PrimaryButton(
                      label: _creatingAccount ? 'Create account' : 'Sign in',
                      busy: session.busy,
                      busyLabel: _creatingAccount
                          ? 'Creating your account…'
                          : 'Signing in…',
                      onPressed: _submit,
                    ),

                    if (!_creatingAccount) ...[
                      const SizedBox(height: Insets.xs),
                      QuietButton(
                        label: 'I forgot my password',
                        onPressed: () => context.push('/reset-password'),
                      ),
                    ],

                    const SizedBox(height: Insets.lg),
                    Divider(color: c.hairline),
                    const SizedBox(height: Insets.sm),
                    Text(
                      _creatingAccount
                          ? 'Already have an account?'
                          : 'New to the app?',
                      style: AppType.bodySmall.copyWith(color: c.inkSoft),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Insets.xs),
                    SecondaryButton(
                      label: _creatingAccount
                          ? 'Sign in instead'
                          : 'Create an account',
                      onPressed: session.busy ? null : _switchMode,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateName(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Please enter your name so your family can recognise you.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Please enter your email address.';
    // Deliberately loose. A strict pattern rejects real addresses, and the
    // server is the one that has to agree anyway.
    if (!email.contains('@') || !email.contains('.') || email.length < 5) {
      return 'That does not look like an email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Please enter your password.';
    if (_creatingAccount && password.length < 6) {
      return 'Please use at least 6 characters.';
    }
    return null;
  }
}
