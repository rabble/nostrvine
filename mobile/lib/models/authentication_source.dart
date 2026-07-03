/// SharedPreferences key under which the current session's
/// [AuthenticationSource] `code` is persisted, so the correct sign-in method
/// can be restored at startup.
const kAuthenticationSourceKey = 'authentication_source';

/// Source of authentication used to restore session at startup
enum AuthenticationSource {
  none('none'),
  divineOAuth('divineOAuth'),
  importedKeys('imported_keys'),
  automatic('automatic'),
  bunker('bunker'),
  amber('amber'),
  nip07('nip07'),
  ;

  const AuthenticationSource(this.code);

  final String code;

  static AuthenticationSource fromCode(String? code) {
    return AuthenticationSource.values
            .where((s) => s.code == code)
            .firstOrNull ??
        AuthenticationSource.none;
  }
}
