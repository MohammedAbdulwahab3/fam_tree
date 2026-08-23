import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:family_tree/core/design/design.dart';
import 'package:family_tree/features/auth/session.dart';

/// Getting back in after forgetting a password.
///
/// There is no mail server, so there is no reset link. An admin issues a code
/// and passes it on however they normally reach that relative — a phone call,
/// a message — and the admin recognising a family member is what stands in for
/// a verification email.
///
/// That is unusual enough that the screen explains it before asking for
/// anything, in two numbered steps. The alternative is a code box with no
/// indication of where the code comes from.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();

  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await ref.read(sessionProvider.notifier).resetPassword(
          email: _email.text.trim(),
          code: _code.text.trim(),
          newPassword: _password.text,
        );

    if (!mounted || !ok) return;

    Toast.success(context, 'Your new password is set.');
    context.go('/tree');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = ref.watch(sessionProvider);

    return AppPage(
      title: 'Forgotten password',
      bottomAction: PrimaryButton(
        label: 'Set new password',
        busy: session.busy,
        busyLabel: 'Setting it…',
        onPressed: _submit,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Step(
              number: 1,
              title: 'Ask an admin for a code',
              body: 'Call or message whoever looks after the family tree. '
                  'They can create a one-time code for you in a few seconds. '
                  'It looks like ABCD-1234 and lasts two hours.',
            ),
            const SizedBox(height: Insets.md),
            const _Step(
              number: 2,
              title: 'Enter it below with a new password',
              body: 'You will be signed in straight away — no need to come '
                  'back to the sign-in screen.',
            ),
            const SizedBox(height: Insets.lg),
            Divider(color: c.hairline),
            const SizedBox(height: Insets.lg),

            AppTextField(
              label: 'Your email',
              controller: _email,
              hint: 'you@example.com',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Please enter the email you signed up with.'
                  : null,
            ),
            const SizedBox(height: Insets.md),

            AppTextField(
              label: 'The code',
              controller: _code,
              hint: 'ABCD-1234',
              icon: Icons.key_outlined,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              helper: 'Upper or lower case, with or without the dash — '
                  'whichever way you write it will work.',
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Please enter the code the admin gave you.'
                  : null,
            ),
            const SizedBox(height: Insets.md),

            AppTextField(
              label: 'New password',
              controller: _password,
              icon: Icons.lock_outline_rounded,
              obscureText: !_showPassword,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.done,
              helper: 'At least 6 characters.',
              onSubmitted: (_) => _submit(),
              validator: (v) => (v ?? '').length < 6
                  ? 'Please use at least 6 characters.'
                  : null,
              suffix: IconButton(
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                tooltip: _showPassword ? 'Hide password' : 'Show password',
              ),
            ),

            if (session.error != null) ...[
              const SizedBox(height: Insets.md),
              AppNotice(message: session.error!, tone: NoticeTone.danger),
            ],
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.body,
  });

  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.accentSoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: AppType.label.copyWith(color: c.accentDeep),
          ),
        ),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppType.bodyStrong.copyWith(color: c.ink)),
              const SizedBox(height: 2),
              Text(body, style: AppType.bodySmall.copyWith(color: c.inkSoft)),
            ],
          ),
        ),
      ],
    );
  }
}
