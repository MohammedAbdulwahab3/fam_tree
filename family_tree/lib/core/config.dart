/// Settings that differ between a developer's machine and a real deployment.
///
/// There used to be two hardcoded `baseUrl` constants — one in [ApiService],
/// one in [AuthService] — both pointing at `http://localhost:5000`, a port the
/// Go server does not listen on. Git history shows the value being hand-edited
/// between a Render URL, an AWS URL and localhost across several commits, with
/// the two copies free to disagree in between.
class AppConfig {
  const AppConfig._();

  /// Where the backend lives.
  ///
  /// Override it at build time; the default is a local server started with
  /// `go run .`, which listens on 8080.
  ///
  ///     flutter run   --dart-define=API_BASE_URL=http://192.168.1.20:8080
  ///     flutter build --dart-define=API_BASE_URL=https://api.example.com
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// The family tree this build shows. One tree per deployment — the app has
  /// no tree picker, so there is nothing to switch between. Must match the
  /// backend's `FAMILY_TREE_ID`.
  static const String familyTreeId = String.fromEnvironment(
    'FAMILY_TREE_ID',
    defaultValue: 'main-family-tree',
  );

  /// True when the app is talking to a server over plain HTTP. Release builds
  /// should always be HTTPS; this is what the startup assertion checks.
  static bool get isInsecureTransport => apiBaseUrl.startsWith('http://');
}
