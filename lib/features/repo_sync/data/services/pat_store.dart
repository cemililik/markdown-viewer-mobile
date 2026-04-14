import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for the optional GitHub Personal Access Token.
///
/// The token is persisted in the platform Keychain (iOS) or
/// Android Keystore-backed EncryptedSharedPreferences. It is
/// never logged, printed, or serialised to non-secure storage.
///
/// The PAT is entirely optional — anonymous access covers the
/// GitHub rate limit for small documentation trees. Users need
/// a PAT only for private repositories or larger repos that hit
/// the 60-requests/hour unauthenticated limit.
class PatStore {
  const PatStore(this._storage);

  final FlutterSecureStorage _storage;

  static const String _key = 'repo_sync.github_pat';

  /// Returns the stored PAT, or `null` if none has been saved.
  Future<String?> read() => _storage.read(key: _key);

  /// Persists [pat]. An empty string is treated as "no token" —
  /// the caller should call [delete] instead of writing `''`.
  Future<void> write(String pat) => _storage.write(key: _key, value: pat);

  /// Removes any stored PAT.
  Future<void> delete() => _storage.delete(key: _key);
}
