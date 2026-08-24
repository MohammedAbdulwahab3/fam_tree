import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Record something that went wrong, for a developer rather than a member.
///
/// Replaces the bare `print` calls that were scattered through the data layer.
/// Two things were wrong with those: `print` writes to stdout in release builds
/// too, so a member's device logged every failed request forever, and the
/// messages included whatever the exception carried — which for a failed
/// request is the URL, and sometimes the body.
///
/// [log] is a no-op in release. Anything a member needs to see should be shown
/// on screen, not logged; [ApiService.ensureOk] already turns a refused request
/// into a message written for a person.
void log(String message, [Object? error, StackTrace? stackTrace]) {
  if (!kDebugMode) return;
  developer.log(
    message,
    name: 'family_tree',
    error: error,
    stackTrace: stackTrace,
  );
}
