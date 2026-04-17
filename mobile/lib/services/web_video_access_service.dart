import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/services/web_video_object_url_factory.dart';

typedef WebVideoHeadRequest = Future<http.Response> Function(Uri uri);
typedef WebVideoGetRequest =
    Future<http.Response> Function(Uri uri, {Map<String, String>? headers});
typedef WebVideoObjectUrlFactory =
    String Function(Uint8List bytes, {String? mimeType});
typedef WebVideoObjectUrlRevoker = void Function(String url);

class ResolvedWebVideoSource {
  const ResolvedWebVideoSource({
    required this.url,
    required this.isObjectUrl,
  });

  final String url;
  final bool isObjectUrl;
}

class WebVideoAccessService {
  WebVideoAccessService({
    WebVideoHeadRequest? headRequest,
    WebVideoGetRequest? getRequest,
    WebVideoObjectUrlFactory? createObjectUrl,
    WebVideoObjectUrlRevoker? revokeObjectUrl,
  }) : _headRequest = headRequest ?? http.head,
       _getRequest = getRequest ?? http.get,
       _createObjectUrl =
           createObjectUrl ??
           ((bytes, {mimeType}) => createWebVideoObjectUrl(
             bytes,
             mimeType: mimeType ?? 'application/octet-stream',
           )),
       _revokeObjectUrl = revokeObjectUrl ?? revokeWebVideoObjectUrl;

  final WebVideoHeadRequest _headRequest;
  final WebVideoGetRequest _getRequest;
  final WebVideoObjectUrlFactory _createObjectUrl;
  final WebVideoObjectUrlRevoker _revokeObjectUrl;

  Future<PlaybackStatus?> confirmFailureStatus(String url) async {
    try {
      final response = await _headRequest(Uri.parse(url));
      return switch (response.statusCode) {
        401 => PlaybackStatus.ageRestricted,
        403 => PlaybackStatus.forbidden,
        404 => PlaybackStatus.notFound,
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  Future<ResolvedWebVideoSource?> resolveAuthenticatedPlayback({
    required String url,
    required Map<String, String> headers,
    String? fallbackMimeType,
  }) async {
    if (headers.isEmpty) {
      return ResolvedWebVideoSource(url: url, isObjectUrl: false);
    }

    final response = await _getRequest(Uri.parse(url), headers: headers);
    if (response.statusCode != 200 && response.statusCode != 206) {
      return null;
    }

    final mimeType =
        response.headers['content-type'] ??
        fallbackMimeType ??
        'application/octet-stream';
    final objectUrl = _createObjectUrl(
      response.bodyBytes,
      mimeType: mimeType,
    );
    return ResolvedWebVideoSource(url: objectUrl, isObjectUrl: true);
  }

  void revokeResolvedSource(ResolvedWebVideoSource source) {
    if (!source.isObjectUrl) return;
    _revokeObjectUrl(source.url);
  }
}
