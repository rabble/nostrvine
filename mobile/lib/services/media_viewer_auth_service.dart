import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';

/// Creates viewer auth headers for media GET requests.
class MediaViewerAuthService {
  MediaViewerAuthService({
    required AuthService authService,
    required BlossomAuthService blossomAuthService,
    required Nip98AuthService nip98AuthService,
  }) : _authService = authService,
       _blossomAuthService = blossomAuthService,
       _nip98AuthService = nip98AuthService;

  final AuthService _authService;
  final BlossomAuthService _blossomAuthService;
  final Nip98AuthService _nip98AuthService;

  bool get canCreateHeaders => _authService.isAuthenticated;

  /// Returns request headers for a media GET, or null when no viewer auth can
  /// be created for the current user/request shape.
  Future<Map<String, String>?> createAuthHeaders({
    String? sha256Hash,
    String? url,
    String? serverUrl,
  }) async {
    if (!_authService.isAuthenticated) {
      return null;
    }

    if (sha256Hash != null && sha256Hash.isNotEmpty) {
      final header = await _blossomAuthService.createGetAuthHeader(
        sha256Hash: sha256Hash,
        serverUrl: serverUrl,
      );
      return _authorizationHeaders(header);
    }

    if (url != null && url.isNotEmpty) {
      final token = await _nip98AuthService.createAuthToken(
        url: url,
        method: HttpMethod.get,
      );
      return _authorizationHeaders(token?.authorizationHeader);
    }

    return null;
  }

  Map<String, String>? _authorizationHeaders(String? authorizationHeader) {
    if (authorizationHeader == null || authorizationHeader.isEmpty) {
      return null;
    }

    return {'Authorization': authorizationHeader};
  }
}
