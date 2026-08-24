import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_tree/core/logging.dart';

/// Where the signed-in member's session lives on the device.
///
/// The JWT goes to the platform keystore — Keychain on iOS, EncryptedSharedPrefs
/// on Android — rather than to SharedPreferences, which stores plain text that
/// anything with filesystem access on a rooted or jailbroken device can read.
/// The token is a 30-day credential, so it is worth the keystore round trip.
///
/// The cached user record stays in SharedPreferences: it is the same data the
/// app renders on screen, and keeping it there avoids a keystore read on every
/// cold start just to show a name.
class SessionStore {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  /// Keys holding data about the signed-in member that must not outlive their
  /// session. The person cache used to survive sign-out entirely, so handing
  /// the phone to a relative and letting them sign in showed them the previous
  /// account's family until the network answered.
  static const _sessionScopedKeys = <String>[
    _userKey,
    'cached_persons',
    'cache_last_updated',
  ];

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Read the stored token, migrating one left behind by an older build.
  static Future<String?> readToken() async {
    try {
      final token = await _secure.read(key: _tokenKey);
      if (token != null) return token;
    } catch (error) {
      // A keystore can be unavailable — a device with no screen lock, a
      // corrupted keychain entry after a restore. Signing the member out is
      // better than crashing on launch.
      log('Could not read the stored session', error);
      return null;
    }

    return _migrateLegacyToken();
  }

  static Future<void> writeToken(String token) async {
    try {
      await _secure.write(key: _tokenKey, value: token);
    } catch (error) {
      log('Could not save the session', error);
    }
  }

  /// Forget everything about the signed-in member, including their cached copy
  /// of the family tree.
  static Future<void> clear() async {
    try {
      await _secure.delete(key: _tokenKey);
    } catch (error) {
      log('Could not clear the stored session', error);
    }

    final prefs = await SharedPreferences.getInstance();
    for (final key in _sessionScopedKeys) {
      await prefs.remove(key);
    }
  }

  static Future<String?> readUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userKey);
  }

  static Future<void> writeUser(String encoded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, encoded);
  }

  /// Move a token written by a build that kept it in SharedPreferences, then
  /// delete the plaintext copy.
  static Future<String?> _migrateLegacyToken() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_tokenKey);
    if (legacy == null) return null;

    await writeToken(legacy);
    await prefs.remove(_tokenKey);
    return legacy;
  }
}
