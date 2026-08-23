import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:family_tree/core/design/design.dart';
import 'package:family_tree/data/services/api_service.dart';
import 'package:family_tree/features/linking/link_status.dart';

/// Where an admin decides who is who.
///
/// The whole decision is "is this person really that relative?", and an admin
/// can only answer it from context — the account's name and email on one side,
/// the tree record's parents, spouses and children on the other. A row of two
/// ids is not a decision anybody can make, so both sides are resolved to names
/// and shown facing each other.
///
/// Rejecting asks for a reason, because a rejection with no explanation leaves
/// the member with nothing to do but claim the same person again.
class ReviewClaimsPage extends ConsumerWidget {
  const ReviewClaimsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(pendingLinkRequestsProvider);

    return AppPage(
      title: 'Who is who',
      subtitle: 'Confirm which people these accounts belong to',
      scrollable: false,
      padding: EdgeInsets.zero,
      constrainWidth: false,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(pendingLinkRequestsProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: requests.when(
        loading: () => const AppLoading(message: 'Loading claims…'),
        error: (error, _) => AppErrorState(
          message: messageForError(error),
          onRetry: () => ref.invalidate(pendingLinkRequestsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const AppEmptyState(
              icon: Icons.done_all_rounded,
              title: 'Nothing waiting',
              message: 'When somebody says which person in the tree they are, '
                  'it will appear here for you to confirm.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pendingLinkRequestsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(Insets.gutter),
              itemCount: list.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: Insets.md),
              itemBuilder: (context, i) {
                if (i == 0) return _Intro(count: list.length);
                return _ClaimCard(request: list[i - 1]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AppNotice(
      tone: NoticeTone.pending,
      title: count == 1 ? 'One person is waiting' : '$count people are waiting',
      message: 'Check the names and relatives match before you approve. '
          'Approving links the account to that record for good — they will '
          'be able to edit it.',
    );
  }
}

class _ClaimCard extends ConsumerStatefulWidget {
  const _ClaimCard({required this.request});

  final LinkRequest request;

  @override
  ConsumerState<_ClaimCard> createState() => _ClaimCardState();
}

class _ClaimCardState extends ConsumerState<_ClaimCard> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    final request = widget.request;
    final personName = request.person?.fullName ?? 'this person';
    final who = request.requester?.name ?? 'This account';

    String? reason;

    if (approve) {
      final taken = request.person?.alreadyClaimedBy;
      final sure = await confirm(
        context,
        title: 'Link $who to $personName?',
        message: taken != null
            ? 'Careful: $personName is already linked to $taken. Approving '
                'this will be refused — unlink the other account first.'
            : '$who will be able to edit $personName\'s profile in the tree.',
        confirmLabel: 'Yes, link them',
        icon: Icons.link_rounded,
        destructive: taken != null,
      );
      if (!sure || !mounted) return;
    } else {
      reason = await _askForReason(personName);
      if (reason == null || !mounted) return;
    }

    setState(() => _busy = true);

    try {
      await ref.read(linkServiceProvider).updateLinkStatus(
            request.id,
            approve ? 'approved' : 'rejected',
            reason: reason,
          );
      ref.invalidate(pendingLinkRequestsProvider);
      if (!mounted) return;

      Toast.success(
        context,
        approve
            ? '$who is now linked to $personName.'
            : 'Turned down. $who has been told why.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      Toast.error(context, messageForError(error));
    }
  }

  /// A rejection without a reason leaves the member guessing, so the field is
  /// offered with examples — but not forced, because an admin who genuinely
  /// has nothing to add should not be blocked.
  Future<String?> _askForReason(String personName) async {
    final controller = TextEditingController();

    final reason = await showAppSheet<String?>(
      context: context,
      title: 'Why not?',
      subtitle: 'They will see this, so it is worth a sentence.',
      initialSize: 0.6,
      body: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(Insets.gutter),
        children: [
          AppTextField(
            label: 'Reason',
            controller: controller,
            hint: 'That is your aunt, not you — look for Meron',
            maxLines: 3,
            autofocus: true,
            optional: true,
            helper: 'Telling them who to look for instead saves another '
                'round of this.',
          ),
          const SizedBox(height: Insets.lg),
          PrimaryButton(
            label: 'Turn down this claim',
            tone: ButtonTone.danger,
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          ),
          const SizedBox(height: Insets.xs),
          SecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );

    controller.dispose();
    return reason;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final request = widget.request;
    final requester = request.requester;
    final person = request.person;

    if (!request.isReviewable) {
      return AppCard(
        tone: c.warning,
        child: Text(
          'This claim is missing its details and cannot be reviewed. '
          'Refresh, and if it stays, the account or the person may have been '
          'deleted.',
          style: AppType.bodySmall.copyWith(color: c.inkSoft),
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              children: [
                _Side(
                  overline: 'This account says',
                  title: requester!.name,
                  subtitle: requester.email,
                  icon: Icons.person_outline_rounded,
                  color: c.info,
                  detail: requester.joinedAt == null
                      ? null
                      : 'Joined ${_when(requester.joinedAt!)}',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: c.hairline)),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Insets.sm,
                        ),
                        child: Text(
                          'is',
                          style: AppType.caption.copyWith(color: c.inkMuted),
                        ),
                      ),
                      Expanded(child: Divider(color: c.hairline)),
                    ],
                  ),
                ),
                _Side(
                  overline: 'this person in the tree',
                  title: person!.fullName,
                  subtitle: [
                    if (person.lifespan.isNotEmpty) person.lifespan,
                    if (person.gender.isNotEmpty) person.gender,
                  ].join(' · '),
                  icon: Icons.account_tree_outlined,
                  color: c.accent,
                ),
                if (person.parentNames.isNotEmpty ||
                    person.spouseNames.isNotEmpty ||
                    person.childNames.isNotEmpty) ...[
                  const SizedBox(height: Insets.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Insets.sm),
                    decoration: BoxDecoration(
                      color: c.surfaceRaised,
                      borderRadius: Corners.medium,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Relatives('Parents', person.parentNames),
                        _Relatives('Married to', person.spouseNames),
                        _Relatives('Children', person.childNames),
                      ],
                    ),
                  ),
                ],
                if (person.alreadyClaimedBy != null) ...[
                  const SizedBox(height: Insets.sm),
                  AppNotice(
                    tone: NoticeTone.danger,
                    title: 'Already taken',
                    message: '${person.fullName} is linked to '
                        '${person.alreadyClaimedBy}. Approving this will be '
                        'refused.',
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: c.hairline),
          Padding(
            padding: const EdgeInsets.all(Insets.sm),
            child: Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Not them',
                    onPressed: _busy ? null : () => _decide(false),
                  ),
                ),
                const SizedBox(width: Insets.xs),
                Expanded(
                  child: PrimaryButton(
                    label: 'Yes, link',
                    busy: _busy,
                    busyLabel: 'Saving…',
                    onPressed: () => _decide(true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _when(DateTime date) {
    final days = DateTime.now().difference(date).inDays;
    if (days < 1) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 30) return '$days days ago';
    if (days < 365) return '${(days / 30).floor()} months ago';
    return '${(days / 365).floor()} years ago';
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.overline,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.detail,
  });

  final String overline;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: Corners.medium,
          ),
          child: Icon(icon, size: Sizes.iconMd, color: color),
        ),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                overline.toUpperCase(),
                style: AppType.overline.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: 2),
              Text(title, style: AppType.subheading.copyWith(color: c.ink)),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: AppType.bodySmall.copyWith(color: c.inkSoft),
                  overflow: TextOverflow.ellipsis,
                ),
              if (detail != null)
                Text(
                  detail!,
                  style: AppType.caption.copyWith(color: c.inkMuted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Relatives extends StatelessWidget {
  const _Relatives(this.label, this.names);

  final String label;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: AppType.caption.copyWith(color: c.inkMuted),
            ),
          ),
          Expanded(
            child: Text(
              names.join(', '),
              style: AppType.bodySmall.copyWith(color: c.ink),
            ),
          ),
        ],
      ),
    );
  }
}
