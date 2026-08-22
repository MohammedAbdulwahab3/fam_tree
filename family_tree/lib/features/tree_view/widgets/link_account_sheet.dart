import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/app_colors.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/services/link_service.dart';
import 'package:family_tree/providers/link_provider.dart';

/// The member-facing half of account linking.
///
/// An account and a person in the tree are separate records; linking is what
/// ties them together, and it is what unlocks editing your own family record.
/// Only an admin can approve the link, so this sheet's job is to let someone
/// find themselves in the tree, send the request, and then see where it stands.
///
/// Open it with [LinkAccountSheet.show].
class LinkAccountSheet extends ConsumerStatefulWidget {
  const LinkAccountSheet({super.key, required this.familyMembers});

  /// The whole tree — the pool of records that can be claimed.
  final List<Person> familyMembers;

  static Future<void> show(
    BuildContext context, {
    required List<Person> familyMembers,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LinkAccountSheet(familyMembers: familyMembers),
    );
  }

  @override
  ConsumerState<LinkAccountSheet> createState() => _LinkAccountSheetState();
}

class _LinkAccountSheetState extends ConsumerState<LinkAccountSheet> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();

  String _query = '';
  Person? _selected;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Records nobody has claimed yet. A person already tied to an account is
  /// not offered — requesting it could only ever be rejected.
  List<Person> get _claimable {
    final unclaimed = widget.familyMembers
        .where((p) => p.authUserId == null || p.authUserId!.isEmpty)
        .toList();

    final query = _query.trim().toLowerCase();
    final matches = query.isEmpty
        ? unclaimed
        : unclaimed
            .where((p) => p.searchableNames
                .any((name) => name.toLowerCase().contains(query)))
            .toList();

    matches.sort((a, b) => a.fullName.toLowerCase().compareTo(
          b.fullName.toLowerCase(),
        ));
    return matches;
  }

  Future<void> _submit() async {
    final person = _selected;
    if (person == null || _submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(linkServiceProvider).requestLink(person.id);
      // The drawer and anything else watching status must not keep showing
      // "not linked" after a successful request.
      ref.invalidate(linkStatusProvider);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _selected = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _readable(e);
      });
    }
  }

  /// Exceptions arrive wrapped a couple of layers deep; the user only wants
  /// the sentence at the bottom.
  static String _readable(Object error) {
    final text = error.toString().replaceAll('Exception: ', '');
    if (text.contains('Pending request already exists')) {
      return 'You already have a request waiting for review.';
    }
    if (text.contains('SocketException') || text.contains('Failed host')) {
      return 'Could not reach the server. Check your connection and try again.';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusAsync = ref.watch(linkStatusProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, sheetScroll) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppTheme.surfaceDark, AppTheme.backgroundDark]
                : [ElegantColors.warmWhite, ElegantColors.cream],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            _grabHandle(isDark),
            _title(isDark),
            Expanded(
              child: statusAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                error: (error, _) => _StatusMessage(
                  icon: Icons.cloud_off_rounded,
                  tone: AppTheme.accentRose,
                  title: 'Could not load your link status',
                  body: _readable(error),
                  isDark: isDark,
                  actionLabel: 'Try again',
                  onAction: () => ref.invalidate(linkStatusProvider),
                ),
                data: (status) => _body(status, isDark, sheetScroll),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(
    LinkStatus status,
    bool isDark,
    ScrollController sheetScroll,
  ) {
    switch (status.status) {
      case 'verified':
        return _StatusMessage(
          icon: Icons.verified_rounded,
          tone: context.colors.secondary,
          title: 'Your account is linked',
          body: 'You can edit your own family record, and the tree opens on '
              'your branch every time you sign in.',
          isDark: isDark,
          actionLabel: 'Done',
          onAction: () => Navigator.pop(context),
        );

      case 'pending':
        return _PendingRequest(
          status: status,
          person: _personById(status.personId),
          isDark: isDark,
          onRefresh: () => ref.invalidate(linkStatusProvider),
        );

      default:
        return _picker(isDark, sheetScroll);
    }
  }

  Person? _personById(String? id) {
    if (id == null) return null;
    for (final person in widget.familyMembers) {
      if (person.id == id) return person;
    }
    return null;
  }

  Widget _picker(bool isDark, ScrollController sheetScroll) {
    final results = _claimable;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: _SearchField(
            controller: _search,
            isDark: isDark,
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _InlineError(message: _error!, isDark: isDark),
          ),
        Expanded(
          child: results.isEmpty
              ? _EmptyResults(query: _query, isDark: isDark)
              : ListView.separated(
                  controller: sheetScroll,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final person = results[index];
                    return _PersonOption(
                      person: person,
                      selected: _selected?.id == person.id,
                      isDark: isDark,
                      onTap: () => setState(
                        () => _selected =
                            _selected?.id == person.id ? null : person,
                      ),
                    );
                  },
                ),
        ),
        _confirmBar(isDark),
      ],
    );
  }

  Widget _confirmBar(bool isDark) {
    final person = _selected;
    final accent = context.colors.accent;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          14 + MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : ElegantColors.warmWhite,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : ElegantColors.champagne,
            ),
          ),
        ),
        child: person == null
            ? Row(
                children: [
                  Icon(Icons.touch_app_rounded,
                      size: 17,
                      color: context.colors.inkMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pick the person you are in the tree',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: context.colors.inkMuted,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'An admin reviews every request before the link is made.',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 13,
                      height: 1.3,
                      color: context.colors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 17),
                      label: Text(
                        _submitting
                            ? 'Sending…'
                            : 'Request to link as ${person.firstName}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _grabHandle(bool isDark) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      decoration: BoxDecoration(
        color: context.colors.hairline,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _title(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Link your account',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: context.colors.ink,
                  ),
                ),
                Text(
                  'Connect this login to your place in the family',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 13.5,
                    color: context.colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.close_rounded,
              color: context.colors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.isDark,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool isDark;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: context.colors.ink,
      ),
      decoration: InputDecoration(
        hintText: 'Search by name',
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: context.colors.inkMuted,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 20,
          color: context.colors.inkMuted,
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : ElegantColors.parchment,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PersonOption extends StatelessWidget {
  const _PersonOption({
    required this.person,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final Person person;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: isDark ? 0.16 : 0.10)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : ElegantColors.warmWhite),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? accent
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : ElegantColors.champagne),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              _PersonAvatar(person: person, isDark: isDark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: context.colors.ink,
                      ),
                    ),
                    Text(
                      _subtitle(person),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 12.5,
                        color: context.colors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedScale(
                scale: selected ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child:
                    Icon(Icons.check_circle_rounded, color: accent, size: 21),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Whatever helps tell two same-named relatives apart.
  static String _subtitle(Person person) {
    final parts = <String>[];
    if (person.lifespan.isNotEmpty) parts.add(person.lifespan);
    final kin = person.relationships.parentIds.length +
        person.relationships.childrenIds.length;
    if (kin > 0) parts.add('$kin close relatives');
    return parts.isEmpty ? 'No dates recorded' : parts.join('  ·  ');
  }
}

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({required this.person, required this.isDark});

  final Person person;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final photo = person.profilePhotoUrl;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (context.colors.secondary)
            .withValues(alpha: 0.18),
        image: photo != null && photo.isNotEmpty
            ? DecorationImage(image: NetworkImage(photo), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: photo != null && photo.isNotEmpty
          ? null
          : Text(
              person.initialsForLocaleTag(null),
              style: GoogleFonts.playfairDisplay(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.accentTeal : ElegantColors.sienna,
              ),
            ),
    );
  }
}

class _PendingRequest extends StatelessWidget {
  const _PendingRequest({
    required this.status,
    required this.person,
    required this.isDark,
    required this.onRefresh,
  });

  final LinkStatus status;
  final Person? person;
  final bool isDark;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final tone = context.colors.gold;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          _StatusIcon(icon: Icons.hourglass_top_rounded, tone: tone),
          const SizedBox(height: 18),
          Text(
            'Waiting for approval',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.colors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            person != null
                ? 'You asked to be linked as ${person!.fullName}. An admin '
                    'needs to approve it before you can edit that record.'
                : 'Your request is in the queue. An admin needs to approve it '
                    'before the link is made.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 14.5,
              height: 1.4,
              color: context.colors.inkSoft,
            ),
          ),
          if (status.requestedAt != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: isDark ? 0.14 : 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tone.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, size: 15, color: tone),
                  const SizedBox(width: 8),
                  Text(
                    'Sent ${_ago(status.requestedAt!)}',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: context.colors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Check again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.inkSoft,
              side: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : ElegantColors.champagne,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _ago(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
    required this.isDark,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String body;
  final bool isDark;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
      child: Column(
        children: [
          _StatusIcon(icon: icon, tone: tone),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.colors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 14.5,
              height: 1.4,
              color: context.colors.inkSoft,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: tone,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              actionLabel,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.icon, required this.tone});

  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tone.withValues(alpha: 0.14),
      ),
      child: Icon(icon, size: 34, color: tone),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.isDark});

  final String message;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentRose.withValues(alpha: isDark ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentRose.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 17, color: AppTheme.accentRose),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.35,
                color: context.colors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.query, required this.isDark});

  final String query;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final searching = query.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching
                  ? Icons.search_off_rounded
                  : Icons.people_outline_rounded,
              size: 42,
              color: context.colors.hairline,
            ),
            const SizedBox(height: 14),
            Text(
              searching
                  ? 'Nobody in the tree matches "$query"'
                  : 'Every record already belongs to an account',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: context.colors.inkSoft,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              searching
                  ? 'Try a different spelling, or the name as an admin would '
                      'have entered it.'
                  : 'Ask an admin to add you to the tree first — then you can '
                      'claim that record here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 13.5,
                height: 1.35,
                color: context.colors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
