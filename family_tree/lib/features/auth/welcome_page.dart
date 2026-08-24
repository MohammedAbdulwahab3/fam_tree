import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:family_tree/core/design/design.dart';
import 'package:family_tree/core/widgets/tree_mark.dart';
import 'package:family_tree/features/auth/session.dart';
import 'package:family_tree/features/linking/link_status.dart';

/// The first thing a new member sees, and where they come back to until an
/// admin has linked them.
///
/// A new account can see the family straight away, but is not yet *in* it —
/// nobody has confirmed which of the people in the tree they are. That
/// distinction is invisible unless somebody explains it, so this screen does,
/// in one sentence, and then offers the single next step.
///
/// It doubles as the waiting room: once a claim is in, this is where the
/// member sees that it is being looked at, or why it was not approved.
class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);
    final status = ref.watch(linkStatusProvider);

    return Scaffold(
      backgroundColor: c.ground,
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () => context.push('/account'),
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Your account',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(linkStatusProvider);
            await ref.read(sessionProvider.notifier).refresh();
          },
          child: ListView(
            padding: const EdgeInsets.all(Insets.gutter),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: Sizes.readableWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: Insets.md),
                      const Center(child: TreeMark(size: 72)),
                      const SizedBox(height: Insets.lg),
                      Text(
                        user == null ? 'Welcome' : 'Welcome, ${user.firstName}',
                        style: AppType.title.copyWith(color: c.ink),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        'This is where the family keeps its history — who '
                        'everyone is, how they are related, and the stories '
                        'worth not losing.',
                        style: AppType.body.copyWith(color: c.inkSoft),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Insets.xl),
                      status.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: Insets.xl),
                          child: AppLoading(),
                        ),
                        error: (_, __) => _NextStep(
                          onFindMe: () => context.go('/tree?findme=1'),
                        ),
                        data: (link) => switch (link.state) {
                          LinkState.verified => const _AllSet(),
                          LinkState.pending => _Waiting(link: link),
                          LinkState.rejected => _Rejected(
                              link: link,
                              onTryAgain: () => context.go('/tree?findme=1'),
                            ),
                          LinkState.notLinked => _NextStep(
                              onFindMe: () => context.go('/tree?findme=1'),
                            ),
                        },
                      ),
                      const SizedBox(height: Insets.lg),
                      Divider(color: c.hairline),
                      const SizedBox(height: Insets.sm),
                      AppRow(
                        icon: Icons.account_tree_outlined,
                        title: 'Look around the family tree',
                        subtitle: 'You can explore it now, linked or not.',
                        onTap: () => context.go('/tree'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nothing claimed yet — the ordinary case for a brand new account.
class _NextStep extends StatelessWidget {
  const _NextStep({required this.onFindMe});

  final VoidCallback onFindMe;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(Insets.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_search_rounded,
                      color: c.accent,
                      size: Sizes.iconMd,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      'Find yourself in the tree',
                      style: AppType.subheading.copyWith(color: c.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              Text(
                'Someone in your family has already added you. Point at which '
                'person is you, and an admin will confirm it.',
                style: AppType.body.copyWith(color: c.inkSoft),
              ),
              const SizedBox(height: Insets.md),
              _Benefit(
                icon: Icons.edit_outlined,
                text: 'Then you can fill in your own story',
              ),
              const SizedBox(height: Insets.xs),
              _Benefit(
                icon: Icons.photo_camera_outlined,
                text: 'Add your photograph, so people recognise you',
              ),
              const SizedBox(height: Insets.lg),
              PrimaryButton(
                label: 'Find myself',
                icon: Icons.search_rounded,
                onPressed: onFindMe,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Icon(icon, size: Sizes.iconSm, color: c.accent),
        const SizedBox(width: Insets.xs),
        Expanded(
          child: Text(
            text,
            style: AppType.bodySmall.copyWith(color: c.inkSoft),
          ),
        ),
      ],
    );
  }
}

/// A claim is in and nobody has looked at it yet.
class _Waiting extends StatelessWidget {
  const _Waiting({required this.link});

  final LinkStatus link;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppNotice(
          tone: NoticeTone.pending,
          title: 'Waiting for an admin',
          message: link.personName == null
              ? 'You have asked to be linked. An admin will confirm it soon.'
              : 'You have said you are ${link.personName}. An admin will '
                  'confirm it soon — you do not need to do anything else.',
        ),
        const SizedBox(height: Insets.md),
        Text(
          'Pull down to check again.',
          style: AppType.bodySmall.copyWith(color: context.colors.inkMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// An admin said no, and — usually — why.
class _Rejected extends StatelessWidget {
  const _Rejected({required this.link, required this.onTryAgain});

  final LinkStatus link;
  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppNotice(
          tone: NoticeTone.warning,
          title: 'That was not the right person',
          message: link.reason?.isNotEmpty == true
              ? 'An admin said: "${link.reason}"'
              : 'An admin did not link you to '
                  '${link.personName ?? 'that person'}. '
                  'You can look again and pick someone else.',
        ),
        const SizedBox(height: Insets.md),
        PrimaryButton(
          label: 'Look again',
          icon: Icons.search_rounded,
          onPressed: onTryAgain,
        ),
      ],
    );
  }
}

/// Linked. Shown briefly before the router sends them on to the tree.
class _AllSet extends StatelessWidget {
  const _AllSet();

  @override
  Widget build(BuildContext context) {
    return const AppNotice(
      tone: NoticeTone.success,
      title: 'You are in',
      message: 'Your account is linked to your record in the family tree.',
    );
  }
}
