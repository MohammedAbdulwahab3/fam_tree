import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:family_tree/core/design/design.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/repositories/person_repository.dart';
import 'package:family_tree/data/services/api_service.dart';
import 'package:family_tree/features/auth/session.dart';
import 'package:family_tree/features/linking/link_status.dart';

/// "Which of these people is you?"
///
/// The hard part of this question is not searching — it is that families reuse
/// names. A tree with four Mohammeds cannot be disambiguated from a list of
/// names, and the previous version of this screen was exactly that list, which
/// meant a member either guessed or gave up.
///
/// So every candidate is shown with the people around them: their parents,
/// their children. "Mohammed, son of Oumer" is a question somebody can answer
/// about themselves; "Mohammed" is not. The final step restates the whole
/// relationship before anything is sent, because a wrong claim costs an admin
/// a rejection and the member another wait.
Future<void> showFindMyselfSheet(
  BuildContext context, {
  required List<Person> people,
}) {
  return showAppSheet<void>(
    context: context,
    title: 'Find yourself in the tree',
    initialSize: 0.9,
    body: (context, scroll) =>
        _FindMyself(people: people, scroll: scroll),
  );
}

class _FindMyself extends ConsumerStatefulWidget {
  const _FindMyself({required this.people, required this.scroll});

  final List<Person> people;
  final ScrollController scroll;

  @override
  ConsumerState<_FindMyself> createState() => _FindMyselfState();
}

class _FindMyselfState extends ConsumerState<_FindMyself> {
  final _search = TextEditingController();

  String _query = '';
  Person? _confirming;
  bool _submitting = false;
  String? _error;

  late final FamilyIndex _index = FamilyIndex(widget.people);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Records nobody has claimed yet.
  ///
  /// A person already tied to an account is not offered at all: claiming one
  /// could only ever be rejected, and seeing it in the list makes a member
  /// think they have found themselves.
  List<Person> get _matches {
    final query = _query.trim();
    final unclaimed = widget.people
        .where((p) => p.authUserId == null || p.authUserId!.isEmpty);

    final matches = query.isEmpty
        ? unclaimed.toList()
        : unclaimed.where((p) => p.matchesNameQuery(query)).toList();

    // Living people first — somebody searching for themselves is alive — then
    // alphabetically so the same search always looks the same.
    matches.sort((a, b) {
      if (a.isDeceased != b.isDeceased) return a.isDeceased ? 1 : -1;
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });
    return matches;
  }

  Future<void> _submit(Person person) async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(linkServiceProvider).requestLink(person.id);
      ref.invalidate(linkStatusProvider);
      if (!mounted) return;

      setState(() {
        _submitting = false;
        _confirming = null;
      });
      Toast.success(
        context,
        'Sent. An admin will confirm you are ${person.fullName}.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = messageForError(error);
      });
    }
  }

  Future<void> _withdraw() async {
    final sure = await confirm(
      context,
      title: 'Withdraw your claim?',
      message: 'You can pick a different person afterwards.',
      confirmLabel: 'Withdraw it',
      cancelLabel: 'Keep waiting',
      icon: Icons.undo_rounded,
    );
    if (!sure || !mounted) return;

    try {
      await ref.read(linkServiceProvider).cancelMyRequest();
      ref.invalidate(linkStatusProvider);
      if (mounted) Toast.show(context, 'Your claim has been withdrawn.');
    } catch (error) {
      if (mounted) Toast.error(context, messageForError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(linkStatusProvider);
    final localeTag = Localizations.localeOf(context).toLanguageTag();

    return status.when(
      loading: () => const AppLoading(),
      error: (error, _) => AppErrorState(
        message: messageForError(error),
        onRetry: () => ref.invalidate(linkStatusProvider),
      ),
      data: (link) => switch (link.state) {
        LinkState.verified => _AlreadyLinked(name: link.personName),
        LinkState.pending => _AwaitingReview(
            link: link,
            onWithdraw: _withdraw,
            scroll: widget.scroll,
          ),
        _ => _confirming != null
            ? _ConfirmStep(
                person: _confirming!,
                index: _index,
                localeTag: localeTag,
                busy: _submitting,
                error: _error,
                scroll: widget.scroll,
                onBack: () => setState(() {
                  _confirming = null;
                  _error = null;
                }),
                onConfirm: () => _submit(_confirming!),
              )
            : _SearchStep(
                controller: _search,
                query: _query,
                matches: _matches,
                index: _index,
                localeTag: localeTag,
                scroll: widget.scroll,
                rejection: link.state == LinkState.rejected ? link : null,
                onQueryChanged: (q) => setState(() => _query = q),
                onPick: (person) => setState(() => _confirming = person),
              ),
      },
    );
  }
}

// ---------------------------------------------------------------- step one --

class _SearchStep extends StatelessWidget {
  const _SearchStep({
    required this.controller,
    required this.query,
    required this.matches,
    required this.index,
    required this.localeTag,
    required this.scroll,
    required this.rejection,
    required this.onQueryChanged,
    required this.onPick,
  });

  final TextEditingController controller;
  final String query;
  final List<Person> matches;
  final FamilyIndex index;
  final String localeTag;
  final ScrollController scroll;
  final LinkStatus? rejection;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Person> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.gutter,
            Insets.md,
            Insets.gutter,
            Insets.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rejection != null) ...[
                AppNotice(
                  tone: NoticeTone.warning,
                  title: 'Your last claim was not approved',
                  message: rejection!.reason?.isNotEmpty == true
                      ? 'An admin said: "${rejection!.reason}"'
                      : 'Pick a different person and try again.',
                ),
                const SizedBox(height: Insets.md),
              ],
              Text(
                'Type your name, or a relative\'s',
                style: AppType.bodyStrong.copyWith(color: c.ink),
              ),
              const SizedBox(height: Insets.xxs),
              Text(
                'Each person is shown with their parents and children, so you '
                'can tell which one is you.',
                style: AppType.bodySmall.copyWith(color: c.inkSoft),
              ),
              const SizedBox(height: Insets.sm),
              TextField(
                controller: controller,
                onChanged: onQueryChanged,
                textCapitalization: TextCapitalization.words,
                style: AppType.body.copyWith(color: c.ink),
                decoration: InputDecoration(
                  hintText: 'Search the family',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            controller.clear();
                            onQueryChanged('');
                          },
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Clear',
                        ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: matches.isEmpty
              ? AppEmptyState(
                  icon: Icons.person_search_rounded,
                  title: query.isEmpty
                      ? 'Everyone has been claimed'
                      : 'Nobody matches "$query"',
                  message: query.isEmpty
                      ? 'Every person in the tree is already linked to an '
                          'account. Ask an admin to add you.'
                      : 'Try part of your first name on its own, or ask an '
                          'admin to add you to the tree.',
                )
              : ListView.separated(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(
                    Insets.gutter,
                    Insets.xs,
                    Insets.gutter,
                    Insets.xl,
                  ),
                  itemCount: matches.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: Insets.xs),
                  itemBuilder: (context, i) => _Candidate(
                    person: matches[i],
                    index: index,
                    localeTag: localeTag,
                    onPick: () => onPick(matches[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

/// One person, shown with enough family around them to be identifiable.
class _Candidate extends StatelessWidget {
  const _Candidate({
    required this.person,
    required this.index,
    required this.localeTag,
    required this.onPick,
  });

  final Person person;
  final FamilyIndex index;
  final String localeTag;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final parents = person.relationships.parentIds
        .map(index.byId)
        .whereType<Person>()
        .map((p) => p.fullNameForLocaleTag(localeTag))
        .toList();
    final children = index
        .childrenOf(person)
        .map((p) => p.shortNameForLocaleTag(localeTag))
        .toList();

    return AppCard(
      onTap: onPick,
      padding: const EdgeInsets.all(Insets.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonAvatar(person: person, localeTag: localeTag),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        person.fullNameForLocaleTag(localeTag),
                        style: AppType.bodyStrong.copyWith(color: c.ink),
                      ),
                    ),
                    if (person.lifespan.isNotEmpty) ...[
                      const SizedBox(width: Insets.xs),
                      Text(
                        person.lifespan,
                        style: AppType.caption.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (parents.isNotEmpty)
                  _Relation(
                    icon: Icons.arrow_upward_rounded,
                    label: parents.length == 1
                        ? 'Child of ${parents.first}'
                        : 'Child of ${parents.join(' and ')}',
                  )
                else
                  _Relation(
                    icon: Icons.park_rounded,
                    label: 'Top of the family',
                  ),
                if (children.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  _Relation(
                    icon: Icons.arrow_downward_rounded,
                    label: children.length <= 3
                        ? 'Parent of ${children.join(', ')}'
                        : 'Parent of ${children.take(3).join(', ')} '
                            'and ${children.length - 3} more',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Insets.xs),
          Icon(Icons.chevron_right_rounded, color: c.inkMuted),
        ],
      ),
    );
  }
}

class _Relation extends StatelessWidget {
  const _Relation({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: c.inkMuted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: AppType.bodySmall.copyWith(color: c.inkSoft),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- step two --

/// Restates the claim in full before it is sent.
class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.person,
    required this.index,
    required this.localeTag,
    required this.busy,
    required this.error,
    required this.scroll,
    required this.onBack,
    required this.onConfirm,
  });

  final Person person;
  final FamilyIndex index;
  final String localeTag;
  final bool busy;
  final String? error;
  final ScrollController scroll;
  final VoidCallback onBack;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final parents = person.relationships.parentIds
        .map(index.byId)
        .whereType<Person>()
        .toList();
    final children = index.childrenOf(person);
    final name = person.fullNameForLocaleTag(localeTag);

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.all(Insets.gutter),
            children: [
              Center(
                child: PersonAvatar(
                  person: person,
                  size: Sizes.avatarXl,
                  localeTag: localeTag,
                  showRing: true,
                ),
              ),
              const SizedBox(height: Insets.md),
              Text(
                'You are saying you are',
                style: AppType.bodySmall.copyWith(color: c.inkSoft),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.xxs),
              Text(
                name,
                style: AppType.title.copyWith(color: c.ink),
                textAlign: TextAlign.center,
              ),
              if (person.lifespan.isNotEmpty) ...[
                const SizedBox(height: Insets.xxs),
                Text(
                  person.lifespan,
                  style: AppType.body.copyWith(color: c.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: Insets.lg),

              if (parents.isNotEmpty)
                _People(
                  title: parents.length == 1 ? 'Your parent' : 'Your parents',
                  people: parents,
                  localeTag: localeTag,
                ),
              if (children.isNotEmpty) ...[
                const SizedBox(height: Insets.md),
                _People(
                  title: children.length == 1
                      ? 'Your child'
                      : 'Your ${children.length} children',
                  people: children,
                  localeTag: localeTag,
                ),
              ],

              const SizedBox(height: Insets.lg),
              const AppNotice(
                tone: NoticeTone.info,
                message: 'An admin will check this before it takes effect. '
                    'If it is not right, they will tell you why and you can '
                    'pick somebody else.',
              ),

              if (error != null) ...[
                const SizedBox(height: Insets.md),
                AppNotice(message: error!, tone: NoticeTone.danger),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(Insets.gutter),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.hairline)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                PrimaryButton(
                  label: 'Yes, this is me',
                  icon: Icons.check_rounded,
                  busy: busy,
                  busyLabel: 'Sending…',
                  onPressed: onConfirm,
                ),
                const SizedBox(height: Insets.xs),
                SecondaryButton(
                  label: 'No, go back',
                  onPressed: busy ? null : onBack,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _People extends StatelessWidget {
  const _People({
    required this.title,
    required this.people,
    required this.localeTag,
  });

  final String title;
  final List<Person> people;
  final String localeTag;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: AppType.overline.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: Insets.xs),
        Wrap(
          spacing: Insets.xs,
          runSpacing: Insets.xs,
          children: [
            for (final person in people)
              Container(
                padding: const EdgeInsets.fromLTRB(4, 4, Insets.sm, 4),
                decoration: BoxDecoration(
                  color: c.surfaceRaised,
                  borderRadius: Corners.pill,
                  border: Border.all(color: c.hairline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PersonAvatar(
                      person: person,
                      size: 28,
                      localeTag: localeTag,
                    ),
                    const SizedBox(width: Insets.xs),
                    Text(
                      person.fullNameForLocaleTag(localeTag),
                      style: AppType.bodySmall.copyWith(color: c.ink),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- other states --

class _AwaitingReview extends StatelessWidget {
  const _AwaitingReview({
    required this.link,
    required this.onWithdraw,
    required this.scroll,
  });

  final LinkStatus link;
  final VoidCallback onWithdraw;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.all(Insets.gutter),
      children: [
        const SizedBox(height: Insets.md),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: c.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.hourglass_top_rounded,
              size: Sizes.iconXl,
              color: c.accent,
            ),
          ),
        ),
        const SizedBox(height: Insets.lg),
        Text(
          'An admin is checking',
          style: AppType.heading.copyWith(color: c.ink),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Insets.xs),
        Text(
          link.personName == null
              ? 'You have asked to be linked. There is nothing more to do.'
              : 'You have said you are ${link.personName}. There is nothing '
                  'more to do — we will tell you as soon as it is confirmed.',
          style: AppType.body.copyWith(color: c.inkSoft),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Insets.xl),
        SecondaryButton(
          label: 'That was the wrong person',
          icon: Icons.undo_rounded,
          onPressed: onWithdraw,
        ),
      ],
    );
  }
}

class _AlreadyLinked extends StatelessWidget {
  const _AlreadyLinked({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.check_circle_outline_rounded,
      title: 'You are already in the tree',
      message: name == null
          ? 'Your account is linked to your record.'
          : 'Your account is linked to $name.',
      actionLabel: 'Close',
      onAction: () => Navigator.of(context).pop(),
    );
  }
}
