import 'package:hls_auth_web_player/hls_auth_web_player.dart';

/// Test double for [HlsAuthWebRuntime]. Records calls and returns
/// pre-programmed results so controller tests can assert decision logic
/// without pulling in any JS.
class FakeHlsAuthWebRuntime implements HlsAuthWebRuntime {
  FakeHlsAuthWebRuntime({
    this.isSupported = true,
    this.mp4Result = HlsAuthWebAttemptResult.ok,
    this.hlsResult = HlsAuthWebAttemptResult.ok,
  });

  @override
  bool isSupported;

  HlsAuthWebAttemptResult mp4Result;
  HlsAuthWebAttemptResult hlsResult;

  final List<String> registeredViewTypes = <String>[];
  final List<Mp4Call> mp4Calls = <Mp4Call>[];
  final List<HlsCall> hlsCalls = <HlsCall>[];
  final List<String> disposedViewTypes = <String>[];

  @override
  void ensureVideoViewFactory(String viewType) {
    registeredViewTypes.add(viewType);
  }

  @override
  Future<HlsAuthWebAttemptResult> loadMp4Blob({
    required String viewType,
    required String url,
    String? authorization,
  }) async {
    mp4Calls.add(
      Mp4Call(viewType: viewType, url: url, authorization: authorization),
    );
    return mp4Result;
  }

  @override
  Future<HlsAuthWebAttemptResult> loadHls({
    required String viewType,
    required String url,
    required AuthHeaderProvider authHeader,
  }) async {
    hlsCalls.add(HlsCall(viewType: viewType, url: url, authHeader: authHeader));
    return hlsResult;
  }

  @override
  Future<void> dispose(String viewType) async {
    disposedViewTypes.add(viewType);
  }
}

/// Captured MP4 blob request.
class Mp4Call {
  const Mp4Call({
    required this.viewType,
    required this.url,
    required this.authorization,
  });

  final String viewType;
  final String url;
  final String? authorization;
}

/// Captured HLS load request.
class HlsCall {
  const HlsCall({
    required this.viewType,
    required this.url,
    required this.authHeader,
  });

  final String viewType;
  final String url;
  final AuthHeaderProvider authHeader;
}
