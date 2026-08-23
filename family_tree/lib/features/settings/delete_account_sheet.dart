import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:family_tree/core/design/design.dart';
import 'package:family_tree/data/services/auth_service.dart';
import 'package:family_tree/features/auth/session.dart';

/// Closing an account for good.
///
/// Two things are worth saying plainly before somebody does this, and both are
/// on the screen rather than in a help page: their record in the family tree
/// stays — it belongs to the family's history, not to a login — and the
/// account itself does not come back.
Future<void> showDeleteAccountSheet(BuildContext context, WidgetRef ref) {
  return showAppSheet<void>(
    context: context,
    title: 'Delete your account',
    initialSize: 0.75,
    body: (context, scroll) => _DeleteAccountForm(scroll: scroll, ref: ref),
  );
}

class _DeleteAccountForm extends StatefulWidget {
  const _DeleteAccountForm({required this.scroll, required this.ref});

  final ScrollController scroll;
  final WidgetRef ref;

  @override
  State<_DeleteAccountForm> createState() => _DeleteAccountFormState();
}

class _DeleteAccountFormState extends State<_DeleteAccountForm> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }

    final sure = await confirm(
      context,
      title: 'Delete your account?',
      message: 'This cannot be undone. You would have to create a new account '
          'and be linked to your record again.',
      confirmLabel: 'Delete my account',
      cancelLabel: 'Keep my account',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!sure || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await AuthService().deleteAccount(password: _password.text);
      if (!mounted) return;

      // The service already signed out; bring the session in step so the
      // router sends us to the sign-in screen rather than a private one.
      await widget.ref.read(sessionProvider.notifier).signOut();
      if (!mounted) return;

      Navigator.of(context).pop();
      context.go('/signin');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.all(Insets.gutter),
      children: [
        AppNotice(
          tone: NoticeTone.info,
          title: 'Your place in the tree stays',
          message: 'Your name, your parents, your children and everything you '
              'wrote about yourself remain in the family history. Only the '
              'login is removed, and the record becomes unclaimed so it can be '
              'linked again later.',
          icon: Icons.account_tree_outlined,
        ),
        const SizedBox(height: Insets.md),
        AppNotice(
          tone: NoticeTone.danger,
          title: 'The account itself does not come back',
          message: 'Your notifications and anything you posted to the feed are '
              'removed with it.',
        ),
        const SizedBox(height: Insets.lg),
        Divider(color: c.hairline),
        const SizedBox(height: Insets.lg),
        AppTextField(
          label: 'Your password',
          controller: _password,
          icon: Icons.lock_outline_rounded,
          obscureText: true,
          textCapitalization: TextCapitalization.none,
          helper: 'So that nobody else can close your account for you.',
          errorText: _error,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: Insets.lg),
        PrimaryButton(
          label: 'Delete my account',
          tone: ButtonTone.danger,
          busy: _busy,
          busyLabel: 'Deleting…',
          onPressed: _submit,
        ),
        const SizedBox(height: Insets.xs),
        SecondaryButton(
          label: 'Keep my account',
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
