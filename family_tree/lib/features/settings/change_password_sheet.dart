import 'package:flutter/material.dart';

import 'package:family_tree/core/design/design.dart';
import 'package:family_tree/data/services/auth_service.dart';

/// Change your own password, knowing the current one.
///
/// The current password is required so that a borrowed unlocked phone cannot
/// lock its owner out of the family tree.
Future<void> showChangePasswordSheet(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    title: 'Change your password',
    subtitle: 'You will stay signed in on this device.',
    initialSize: 0.7,
    body: (context, scroll) => _ChangePasswordForm(scroll: scroll),
  );
}

class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm({required this.scroll});

  final ScrollController scroll;

  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();

  bool _busy = false;
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await AuthService().changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      Toast.success(context, 'Your password has been changed.');
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
    return Form(
      key: _formKey,
      child: ListView(
        controller: widget.scroll,
        padding: const EdgeInsets.all(Insets.gutter),
        children: [
          AppTextField(
            label: 'Your current password',
            controller: _current,
            icon: Icons.lock_outline_rounded,
            obscureText: !_show,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.next,
            autofocus: true,
            validator: (v) => (v ?? '').isEmpty
                ? 'Please enter your current password.'
                : null,
          ),
          const SizedBox(height: Insets.md),
          AppTextField(
            label: 'New password',
            controller: _next,
            icon: Icons.lock_reset_rounded,
            obscureText: !_show,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.done,
            helper: 'At least 6 characters.',
            onSubmitted: (_) => _submit(),
            validator: (v) {
              final value = v ?? '';
              if (value.length < 6) return 'Please use at least 6 characters.';
              if (value == _current.text) {
                return 'That is the same as your current password.';
              }
              return null;
            },
            suffix: IconButton(
              onPressed: () => setState(() => _show = !_show),
              icon: Icon(
                _show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              ),
              tooltip: _show ? 'Hide passwords' : 'Show passwords',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: Insets.md),
            AppNotice(message: _error!, tone: NoticeTone.danger),
          ],
          const SizedBox(height: Insets.lg),
          PrimaryButton(
            label: 'Change password',
            busy: _busy,
            busyLabel: 'Changing it…',
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
