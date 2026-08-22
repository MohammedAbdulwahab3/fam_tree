import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:family_tree/data/services/link_service.dart';

/// Providers for account↔person linking.
///
/// These used to live inside the admin dashboard, which meant the member-facing
/// link flow would have had to import an admin screen to read its own status.
/// They belong here, where both sides can reach them.

final linkServiceProvider = Provider<LinkService>((ref) => LinkService());

/// Where the signed-in account stands: verified, pending review, or unlinked.
final linkStatusProvider = FutureProvider<LinkStatus>((ref) async {
  return ref.watch(linkServiceProvider).getMyLinkStatus();
});

/// Every request waiting on an admin decision. Admin-only endpoint.
final pendingLinkRequestsProvider =
    FutureProvider<List<LinkRequest>>((ref) async {
  return ref.watch(linkServiceProvider).getPendingRequests();
});
