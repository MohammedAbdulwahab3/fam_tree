import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:family_tree/core/config.dart';
import 'package:family_tree/core/logging.dart';
import 'package:family_tree/data/services/auth_service.dart';

/// A request the backend refused, carrying the message it gave us.
///
/// The backend answers every failure with `{"error": "..."}` written for a
/// person to read ("You can only delete your own posts"). Wrapping that in a
/// typed exception is what lets the UI show it instead of a status code.
class ApiException implements Exception {
  ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  /// True when the caller is not allowed to do this, as opposed to something
  /// having gone wrong. Worth distinguishing because the UI should not offer a
  /// retry for it.
  bool get isPermissionDenied => statusCode == 403;

  /// True when whatever we were acting on is already gone. Deleting something
  /// that no longer exists is usually the outcome the user wanted anyway.
  bool get isMissing => statusCode == 404;

  @override
  String toString() => message;
}

/// The sentence to put in front of a user for a caught error.
///
/// [ApiException] already carries a message written for a person, so it is used
/// as-is. Anything else is almost always the network being unreachable, which
/// is worth saying plainly rather than leaking a stack-trace-shaped string into
/// a snackbar.
String messageForError(Object error) {
  if (error is ApiException) return error.message;

  final text = error.toString();
  const networkHints = [
    'SocketException',
    'Connection refused',
    'Connection closed',
    'Failed host lookup',
    'ClientException',
    'Network is unreachable',
    'TimeoutException',
  ];
  for (final hint in networkHints) {
    if (text.contains(hint)) {
      return 'No connection to the server. Check your internet and try again.';
    }
  }
  return text;
}

/// Why the server refused to accept who we say we are.
enum AuthFailureKind {
  /// The token was missing, malformed, or too old.
  expired,

  /// An admin suspended the account.
  suspended,

  /// The account no longer exists.
  gone,
}

/// A rejected credential, with the sentence to put in front of the user.
class AuthFailure {
  const AuthFailure(this.kind, this.message);

  final AuthFailureKind kind;
  final String message;
}

class ApiService {
  /// Called when any request is rejected because of who is asking.
  ///
  /// The session controller installs this so an expired token is handled once,
  /// in one place, rather than by each of the forty call sites guessing what a
  /// 401 means. Before this, an expired session showed as an empty family tree
  /// and a silent failure on every write.
  static Future<void> Function(AuthFailure failure)? onAuthFailure;

  /// Inspects a response for a credential problem and reports it. Returns true
  /// when the response was an auth failure, so callers can stop early.
  static bool _reportAuthFailure(http.Response response) {
    if (response.statusCode != 401 && response.statusCode != 403) return false;

    String? serverMessage;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        serverMessage = decoded['error'] as String?;
      }
    } catch (_) {
      // A body we cannot read changes nothing about the status code.
    }

    // A 403 is only about the credential when the server says the account is
    // suspended. Every other 403 is an ordinary permission refusal — a member
    // trying to delete somebody else's post — and must not sign them out.
    final suspended = serverMessage != null &&
        serverMessage.toLowerCase().contains('suspend');

    if (response.statusCode == 403 && !suspended) return false;

    final AuthFailure failure;
    if (suspended) {
      failure = AuthFailure(
        AuthFailureKind.suspended,
        serverMessage,
      );
    } else if (serverMessage != null &&
        serverMessage.toLowerCase().contains('no longer exists')) {
      failure = const AuthFailure(
        AuthFailureKind.gone,
        'This account no longer exists.',
      );
    } else {
      failure = const AuthFailure(
        AuthFailureKind.expired,
        'You have been signed out. Sign in again to continue.',
      );
    }

    onAuthFailure?.call(failure);
    return true;
  }

  /// Where the backend lives. Set at build time — see [AppConfig].
  static const String baseUrl = AppConfig.apiBaseUrl;

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Restores the stored session; delegates to [AuthService].
  Future<void> init() => AuthService().init().then((_) {});

  /// Headers for a backend call. Authenticated requests carry the JWT that
  /// `/login` issued — the server verifies its signature, so unlike the old
  /// email header it cannot be forged by the caller.
  Future<Map<String, String>> _getHeaders({
    bool includeAuth = true,
    Map<String, String>? extra,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (includeAuth) {
      final token = AuthService().token;
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  // POST request
  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(includeAuth: includeAuth);
    final response = await http.post(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    if (includeAuth) _reportAuthFailure(response);
    return response;
  }

  // GET request. [headers] adds request headers such as If-None-Match.
  Future<http.Response> get(
    String endpoint, {
    bool includeAuth = true,
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final merged = await _getHeaders(includeAuth: includeAuth, extra: headers);
    final response = await http.get(
      url,
      headers: merged,
    );
    if (includeAuth) _reportAuthFailure(response);
    return response;
  }

  // PUT request
  Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(includeAuth: includeAuth);
    final response = await http.put(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    if (includeAuth) _reportAuthFailure(response);
    return response;
  }

  // DELETE request
  Future<http.Response> delete(
    String endpoint, {
    bool includeAuth = true,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(includeAuth: includeAuth);
    final response = await http.delete(
      url,
      headers: headers,
    );
    if (includeAuth) _reportAuthFailure(response);
    return response;
  }

  /// Throws an [ApiException] unless the response is a success.
  ///
  /// Every write in the app used to ignore the status code, so a request that
  /// 404'd or 403'd looked exactly like one that worked — the UI updated
  /// optimistically and then quietly reverted on the next poll. Routing every
  /// mutation through here is what makes a failure visible.
  static void ensureOk(http.Response response, {required String whileDoing}) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String message;
    try {
      final decoded = jsonDecode(response.body);
      final error = decoded is Map<String, dynamic> ? decoded['error'] : null;
      message = error is String && error.trim().isNotEmpty
          ? error
          : _fallbackMessage(response.statusCode, whileDoing);
    } catch (_) {
      message = _fallbackMessage(response.statusCode, whileDoing);
    }

    throw ApiException(message, response.statusCode);
  }

  static String _fallbackMessage(int statusCode, String whileDoing) {
    switch (statusCode) {
      case 401:
        return 'Your session has expired. Sign in again to continue.';
      case 403:
        return 'You do not have permission to do that.';
      case 404:
        return 'That is no longer available.';
      case 409:
        return 'That conflicts with something that already exists.';
      default:
        if (statusCode >= 500) {
          return 'The server had a problem $whileDoing. Try again in a moment.';
        }
        return 'Something went wrong $whileDoing.';
    }
  }

  /// Upload a file, reporting progress as it goes.
  ///
  /// [onProgress] receives a value from 0.0 to 1.0 as the body is sent. Without
  /// it the UI can only show an indeterminate spinner, which on a slow
  /// connection is indistinguishable from the app having hung.
  Future<String?> uploadFile(
    String filePath,
    List<int> fileBytes, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/upload');
      final request = http.MultipartRequest('POST', url);

      final token = AuthService().token;
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: filePath.split('/').last,
        ),
      );

      final http.StreamedResponse streamedResponse;
      if (onProgress == null) {
        streamedResponse = await request.send();
      } else {
        streamedResponse = await _sendWithProgress(request, onProgress);
      }

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return '$baseUrl${data['url']}';
      }
      // Surface the server's reason — "that file is too large" is worth saying,
      // and used to be swallowed into a bare null.
      ensureOk(response, whileDoing: 'uploading the file');
      return null;
    } catch (error, stack) {
      if (error is ApiException) rethrow;
      log('Upload failed', error, stack);
      return null;
    }
  }

  /// Sends [request] while counting the bytes handed to the socket.
  ///
  /// `MultipartRequest.send` gives no progress, so the finalized body stream is
  /// wrapped in one that reports as it is drained.
  Future<http.StreamedResponse> _sendWithProgress(
    http.MultipartRequest request,
    void Function(double progress) onProgress,
  ) async {
    final total = request.contentLength;
    var sent = 0;

    final source = request.finalize();
    final counted = source.transform<List<int>>(
      StreamTransformer.fromHandlers(
        handleData: (chunk, sink) {
          sent += chunk.length;
          if (total > 0) {
            onProgress((sent / total).clamp(0.0, 1.0));
          }
          sink.add(chunk);
        },
        handleDone: (sink) {
          onProgress(1.0);
          sink.close();
        },
      ),
    );

    final streamed = http.StreamedRequest(request.method, request.url)
      ..headers.addAll(request.headers)
      ..contentLength = total;

    // Pump the counted stream into the outgoing request.
    unawaited(
      counted
          .listen(
            streamed.sink.add,
            onError: streamed.sink.addError,
            onDone: streamed.sink.close,
            cancelOnError: true,
          )
          .asFuture<void>(),
    );

    return _client.send(streamed);
  }

  final http.Client _client = http.Client();
}
