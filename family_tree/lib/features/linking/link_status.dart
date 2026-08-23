import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:family_tree/data/services/link_service.dart';
import 'package:family_tree/features/auth/session.dart';

export 'package:family_tree/data/services/link_service.dart'
    show LinkStatus, LinkRequest, LinkRequester, LinkTargetPerson;

/// Where a member stands with being linked to somebody in the tree.
///
/// The server sends this as a string. Turning it into an enum at the boundary
/// is what lets the screens switch exhaustively over it — so a state added
/// later is a compile error at every screen that has to handle it, rather than
/// a blank panel at runtime.
enum LinkState {
  /// Never claimed anybody, or withdrew the claim.
  notLinked,

  /// Claimed somebody; an admin has not decided yet.
  pending,

  /// An admin said no. [LinkStatus.reason] usually says why.
  rejected,

  /// An admin approved it. The account owns a record in the tree.
  verified,
}

extension LinkStatusState on LinkStatus {
  LinkState get state => switch (status) {
        'verified' => LinkState.verified,
        'pending' => LinkState.pending,
        'rejected' => LinkState.rejected,
        _ => isVerified ? LinkState.verified : LinkState.notLinked,
      };
}

final linkServiceProvider = Provider<LinkService>((ref) => LinkService());

/// The signed-in member's own claim status.
///
/// Watches the session so that signing out, or an admin approving the claim,
/// re-reads it rather than leaving a stale answer on screen.
final linkStatusProvider = FutureProvider<LinkStatus>((ref) async {
  final signedIn = ref.watch(isSignedInProvider);
  if (!signedIn) {
    return LinkStatus(isVerified: false, status: 'not_linked');
  }

  final status = await ref.watch(linkServiceProvider).getMyLinkStatus();

  // An approval arrives here before it arrives on the account, because the app
  // asks about the claim more often than it re-reads /api/me. Nudging the
  // session keeps the router's isLinked in step, so an approved member is not
  // left sitting on the welcome screen.
  if (status.isVerified && !ref.read(sessionProvider).isLinked) {
    Future.microtask(() => ref.read(sessionProvider.notifier).refresh());
  }

  return status;
});

/// The queue of claims waiting for an admin.
final pendingLinkRequestsProvider =
    FutureProvider<List<LinkRequest>>((ref) async {
  if (!ref.watch(isAdminProvider)) return const [];
  return ref.watch(linkServiceProvider).getPendingRequests();
});

/// How many claims are waiting — for the badge on the admin entry point.
final pendingLinkCountProvider = Provider<int>((ref) {
  return ref.watch(pendingLinkRequestsProvider).maybeWhen(
        data: (requests) => requests.length,
        orElse: () => 0,
      );
});
