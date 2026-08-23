import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/core/config.dart';
import 'package:family_tree/data/services/api_service.dart';
import 'package:family_tree/data/services/auth_service.dart';

/// There used to be two hardcoded `baseUrl` constants, both pointing at
/// `http://localhost:5000` — a port the Go server does not listen on — and free
/// to drift apart. These pin them together.
void main() {
  test('both services read the same base URL', () {
    expect(ApiService.baseUrl, AppConfig.apiBaseUrl);
    expect(AuthService.baseUrl, AppConfig.apiBaseUrl);
  });

  test('the default points at a locally running backend', () {
    // The Go server defaults to :8080. The app defaulting to :5000 meant a
    // fresh checkout could not talk to a fresh checkout.
    expect(AppConfig.apiBaseUrl, isNot(contains(':5000')));
  });

  test('a plain-HTTP base URL is recognised as insecure', () {
    expect('http://localhost:8080'.startsWith('http://'), isTrue);
    expect(
      AppConfig.isInsecureTransport,
      AppConfig.apiBaseUrl.startsWith('http://'),
    );
  });

  test('the family tree id is not empty', () {
    expect(AppConfig.familyTreeId, isNotEmpty);
  });
}
