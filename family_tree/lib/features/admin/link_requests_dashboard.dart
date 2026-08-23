import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/elegant_theme.dart';
import '../../data/services/api_service.dart';
import '../../data/services/link_service.dart';
import 'package:family_tree/features/linking/link_status.dart';

/// Admin review of "this account says it is this person in the tree".
///
/// The decision is a factual one — is this really them? — so the card leads
/// with the two identities side by side and the family the claimed record sits
/// in. The previous version printed the two raw UUIDs, which told an admin
/// nothing they could act on.
class LinkRequestsDashboard extends ConsumerWidget {
  const LinkRequestsDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final requestsAsync = ref.watch(pendingLinkRequestsProvider);

    return Scaffold(
      backgroundColor:
          context.colors.ground,
      appBar: AppBar(
        title: Text(
          'Link requests',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(pendingLinkRequestsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error.toString().replaceAll('Exception: ', ''),
          isDark: isDark,
          onRetry: () => ref.invalidate(pendingLinkRequestsProvider),
        ),
        data: (requests) {
          if (requests.isEmpty) return _EmptyState(isDark: isDark);

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            itemCount: requests.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _Intro(count: requests.length, isDark: isDark);
              }
              return _RequestCard(
                request: requests[index - 1],
                isDark: isDark,
              );
            },
          );
        },
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.count, required this.isDark});

  final int count;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 4),
      child: Text(
        count == 1
            ? '1 person is waiting to be connected to their record in the tree.'
            : '$count people are waiting to be connected to their records in '
                'the tree.',
        style: GoogleFonts.cormorantGaramond(
          fontSize: 15,
          height: 1.35,
          color: context.colors.inkSoft,
        ),
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({required this.request, required this.isDark});

  final LinkRequest request;
  final bool isDark;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _working = false;

  Future<void> _decide(bool approve) async {
    final request = widget.request;
    final person = request.person;

    // Approving a record someone else owns would silently steal it, so make
    // the admin acknowledge that specifically.
    if (approve && person?.alreadyClaimedBy != null) {
      final proceed = await _confirm(
        title: 'That record is already taken',
        body: '${person!.fullName} is already linked to '
            '${person.alreadyClaimedBy}. Approving this moves the record to '
            '${request.requester?.email ?? 'this account'}.',
        confirmLabel: 'Move it anyway',
        danger: true,
      );
      if (proceed != true) return;
    }

    String? reason;
    if (!approve) {
      reason = await _askForReason();
      // Null means the admin backed out; an empty string means they chose to
      // reject without giving one.
      if (reason == null) return;
    }

    setState(() => _working = true);
    try {
      await ref.read(linkServiceProvider).updateLinkStatus(
            request.id,
            approve ? 'approved' : 'rejected',
            reason: reason,
          );
      ref.invalidate(pendingLinkRequestsProvider);
      if (!mounted) return;
      _toast(
        approve
            ? '${request.requester?.name ?? 'Account'} is now linked to '
                '${request.person?.fullName ?? 'that record'}'
            : '${request.requester?.name ?? 'They'} have been told why',
        approve,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      _toast(messageForError(e), false);
    }
  }

  /// Asks why the claim is being turned down. Returns the reason, an empty
  /// string if the admin declined to give one, or null if they backed out.
  ///
  /// The member sees this text, so it is the difference between "your claim was
  /// not approved" and knowing what to do next.
  Future<String?> _askForReason() async {
    final controller = TextEditingController();
    final requester = widget.request.requester?.name ?? 'This account';

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Why not approve?',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$requester will see this, so say what would help them get it '
              'right next time.',
              style: GoogleFonts.inter(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. That is your uncle, not you — try Aster Bekele',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: Text('Reject without a reason', style: GoogleFonts.inter()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text('Reject', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    bool danger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: GoogleFonts.playfairDisplay(
          fontWeight: FontWeight.w700,
        )),
        content: Text(body, style: GoogleFonts.inter(fontSize: 14, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  danger ? AppTheme.accentRose : AppTheme.primaryLight,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _toast(String message, bool good) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: good ? AppTheme.primaryDeep : AppTheme.accentRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final request = widget.request;
    final requester = request.requester;
    final person = request.person;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : ElegantColors.champagne,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: ElegantColors.warmGray.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'Is this the same person?',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: context.colors.inkMuted,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _IdentityPair(
              requester: requester,
              person: person,
              isDark: isDark,
            ),
          ),
          if (person != null &&
              (person.parentNames.isNotEmpty ||
                  person.spouseNames.isNotEmpty ||
                  person.childNames.isNotEmpty))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _FamilyContext(person: person, isDark: isDark),
            ),
          if (person?.alreadyClaimedBy != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _Warning(
                message: 'Already linked to ${person!.alreadyClaimedBy}. '
                    'Approving moves the record to this account.',
                isDark: isDark,
              ),
            ),
          if (!request.isReviewable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _Warning(
                message: 'Some details could not be loaded — the account or '
                    'the record may have been deleted.',
                isDark: isDark,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: context.colors.inkMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Asked ${_ago(request.requestedAt)}',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 13,
                      color:
                          context.colors.inkMuted,
                    ),
                  ),
                ),
                if (_working)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  TextButton.icon(
                    onPressed: () => _decide(false),
                    icon: const Icon(Icons.close_rounded, size: 17),
                    label: const Text('Reject'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accentRose,
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: () => _decide(true),
                    icon: const Icon(Icons.check_rounded, size: 17),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryDeep,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                ],
              ],
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
    if (diff.inDays < 30) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    return 'on ${DateFormat('d MMM yyyy').format(when)}';
  }
}

/// The account on the left, the tree record on the right, an equals-ish link
/// between them — the question the admin is answering, drawn.
class _IdentityPair extends StatelessWidget {
  const _IdentityPair({
    required this.requester,
    required this.person,
    required this.isDark,
  });

  final LinkRequester? requester;
  final LinkTargetPerson? person;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _IdentityColumn(
              label: 'Account',
              title: requester?.name ?? 'Unknown account',
              subtitle: requester?.email ?? '',
              extra: requester?.joinedAt != null
                  ? 'Joined ${DateFormat('MMM yyyy').format(requester!.joinedAt!)}'
                  : null,
              photoUrl: requester?.photoUrl ?? '',
              tone: context.colors.secondary,
              isDark: isDark,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Icon(
                Icons.sync_alt_rounded,
                size: 18,
                color: context.colors.inkMuted,
              ),
            ),
          ),
          Expanded(
            child: _IdentityColumn(
              label: 'Tree record',
              title: person?.fullName ?? 'Unknown record',
              subtitle: person?.lifespan ?? '',
              extra: (person?.gender.isNotEmpty ?? false)
                  ? _capitalise(person!.gender)
                  : null,
              photoUrl: person?.photoUrl ?? '',
              tone: context.colors.gold,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalise(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}

class _IdentityColumn extends StatelessWidget {
  const _IdentityColumn({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.extra,
    required this.photoUrl,
    required this.tone,
    required this.isDark,
  });

  final String label;
  final String title;
  final String subtitle;
  final String? extra;
  final String photoUrl;
  final Color tone;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: isDark ? 0.10 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: tone,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tone.withValues(alpha: 0.2),
                  image: photoUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(photoUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: photoUrl.isNotEmpty
                    ? null
                    : Text(
                        _initials(title),
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tone,
                        ),
                      ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: context.colors.ink,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: context.colors.inkMuted,
              ),
            ),
          ],
          if (extra != null) ...[
            const SizedBox(height: 3),
            Text(
              extra!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 12.5,
                color: context.colors.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// The relatives of the claimed record. This is what usually settles it — an
/// admin who knows the family recognises the parents and children instantly.
class _FamilyContext extends StatelessWidget {
  const _FamilyContext({required this.person, required this.isDark});

  final LinkTargetPerson person;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : ElegantColors.parchment,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${person.fullName} in the tree',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: context.colors.inkMuted,
            ),
          ),
          const SizedBox(height: 9),
          if (person.parentNames.isNotEmpty)
            _row(context, 'Parents', person.parentNames, Icons.escalator_warning_rounded),
          if (person.spouseNames.isNotEmpty)
            _row(context, 'Spouse', person.spouseNames, Icons.favorite_rounded),
          if (person.childNames.isNotEmpty)
            _row(context, 'Children', person.childNames, Icons.child_care_rounded),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, List<String> names,
      IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 14,
            color: context.colors.inkMuted,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.colors.inkSoft,
              ),
            ),
          ),
          Expanded(
            child: Text(
              names.join(', '),
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.35,
                color: context.colors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.message, required this.isDark});

  final String message;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const tone = AppTheme.warning;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: tone),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 52,
              color: context.colors.hairline,
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing to review',
              style: GoogleFonts.playfairDisplay(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: context.colors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'When someone asks to be connected to their record in the tree, '
              'their request lands here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 14.5,
                height: 1.4,
                color: context.colors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.isDark,
    required this.onRetry,
  });

  final String message;
  final bool isDark;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppTheme.accentRose),
            const SizedBox(height: 14),
            Text(
              'Could not load requests',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.colors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: context.colors.inkMuted,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
