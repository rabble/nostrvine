import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/widgets/avatar_failure_cache.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

class _MockMediaCacheManager extends Mock implements MediaCacheManager {}

final Uint8List _transparentImageBytes = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

void main() {
  Widget buildAvatar({String? imageUrl}) {
    return MaterialApp(
      home: Scaffold(
        body: UserAvatar(imageUrl: imageUrl, name: 'Test User'),
      ),
    );
  }

  Future<void> pumpAvatarWithValidSvgResponse(
    WidgetTester tester,
    String imageUrl,
  ) {
    return HttpOverrides.runZoned(
      () async {
        await tester.pumpWidget(buildAvatar(imageUrl: imageUrl));
        await tester.pump();
      },
      createHttpClient: (_) => _ValidSvgHttpClient(),
    );
  }

  Finder gradientPlaceholderFinder() => find.byWidgetPredicate((widget) {
    if (widget is! DecoratedBox) return false;
    final decoration = widget.decoration;
    return decoration is BoxDecoration && decoration.gradient != null;
  }, description: 'generated avatar placeholder');

  setUp(() {
    AvatarFailureCache.instance.clear();
    AvatarFailureCache.instance.resetClockForTesting();
  });

  tearDown(() {
    AvatarFailureCache.instance.clear();
    AvatarFailureCache.instance.resetClockForTesting();
  });

  group('UserAvatar.isSvgImageUrl', () {
    test('returns true for svg URLs', () {
      expect(
        UserAvatar.isSvgImageUrl('https://divine.video/divine-logo.svg'),
        isTrue,
      );
      expect(
        UserAvatar.isSvgImageUrl(
          'https://divine.video/divine-logo.svg?size=128',
        ),
        isTrue,
      );
      expect(
        UserAvatar.isSvgImageUrl(
          'https://divine.video/assets/DIVINE-LOGO.SVG#avatar',
        ),
        isTrue,
      );
    });

    test('returns false for non-svg or invalid URLs', () {
      expect(
        UserAvatar.isSvgImageUrl('https://divine.video/avatar.png'),
        isFalse,
      );
      expect(UserAvatar.isSvgImageUrl('not a url'), isFalse);
      expect(UserAvatar.isSvgImageUrl(null), isFalse);
      expect(UserAvatar.isSvgImageUrl(''), isFalse);
    });
  });

  group('UserAvatar rendering', () {
    testWidgets('skips SvgPicture for cached failed SVG avatar URLs', (
      tester,
    ) async {
      const failedUrl = 'https://divine.video/divine-logo.svg';
      AvatarFailureCache.instance.recordFailure(
        failedUrl,
        ttl: AvatarFailureCache.deterministicFailureTtl,
      );

      await tester.pumpWidget(buildAvatar(imageUrl: failedUrl));

      expect(find.byType(SvgPicture), findsNothing);
      expect(find.byType(VineCachedImage), findsNothing);
      expect(gradientPlaceholderFinder(), findsAtLeastNWidgets(1));
    });

    testWidgets('skips VineCachedImage for cached failed raster avatar URLs', (
      tester,
    ) async {
      const failedUrl = 'https://divine.video/avatar.png';
      AvatarFailureCache.instance.recordFailure(
        failedUrl,
        ttl: AvatarFailureCache.deterministicFailureTtl,
      );

      await tester.pumpWidget(buildAvatar(imageUrl: failedUrl));

      expect(find.byType(SvgPicture), findsNothing);
      expect(find.byType(VineCachedImage), findsNothing);
      expect(gradientPlaceholderFinder(), findsAtLeastNWidgets(1));
    });

    testWidgets('cached failures are scoped to the exact avatar URL', (
      tester,
    ) async {
      const failedUrl = 'https://divine.video/broken-avatar.png';
      const workingUrl = 'https://divine.video/avatar.png';
      AvatarFailureCache.instance.recordFailure(
        failedUrl,
        ttl: AvatarFailureCache.deterministicFailureTtl,
      );

      await tester.pumpWidget(buildAvatar(imageUrl: failedUrl));
      expect(find.byType(VineCachedImage), findsNothing);

      await tester.pumpWidget(buildAvatar(imageUrl: workingUrl));
      expect(find.byType(VineCachedImage), findsOneWidget);
      expect(
        tester.widget<VineCachedImage>(find.byType(VineCachedImage)).imageUrl,
        workingUrl,
      );
    });

    testWidgets('raster deterministic failures are cached', (tester) async {
      const failedUrl = 'https://divine.video/avatar.png';

      await tester.pumpWidget(buildAvatar(imageUrl: failedUrl));
      final image = tester.widget<VineCachedImage>(
        find.byType(VineCachedImage),
      );

      image.errorWidget!(
        tester.element(find.byType(VineCachedImage)),
        failedUrl,
        Exception('Invalid image data'),
      );

      expect(AvatarFailureCache.instance.isFailed(failedUrl), isTrue);
    });

    testWidgets('SVG transient failures are cached briefly', (tester) async {
      const failedUrl = 'https://divine.video/divine-logo.svg';

      await pumpAvatarWithValidSvgResponse(tester, failedUrl);
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));

      svg.errorBuilder!(
        tester.element(find.byType(SvgPicture)),
        Exception('HTTP 503'),
        StackTrace.current,
      );

      expect(AvatarFailureCache.instance.isFailed(failedUrl), isTrue);
    });

    testWidgets('caches malformed SVG errors from the real parser', (
      tester,
    ) async {
      const failedUrl = 'https://divine.video/malformed-avatar.svg';
      Object? parsingError;

      await tester.pumpWidget(
        SvgPicture.string(
          '<!-- invalid svg -->',
          errorBuilder: (context, error, stackTrace) {
            parsingError = error;
            return const SizedBox.shrink();
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(parsingError, isNotNull);
      expect(
        AvatarFailureCache.classifyFailure(parsingError!),
        AvatarFailureKind.deterministic,
      );

      await pumpAvatarWithValidSvgResponse(tester, failedUrl);
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      svg.errorBuilder!(
        tester.element(find.byType(SvgPicture)),
        parsingError!,
        StackTrace.current,
      );

      expect(AvatarFailureCache.instance.isFailed(failedUrl), isTrue);
    });

    testWidgets('raster completed download failures are cached', (
      tester,
    ) async {
      const failedUrl = 'https://blotcdn.com/broken-avatar.png';

      await tester.pumpWidget(buildAvatar(imageUrl: failedUrl));
      final image = tester.widget<VineCachedImage>(
        find.byType(VineCachedImage),
      );

      image.errorWidget!(
        tester.element(find.byType(VineCachedImage)),
        failedUrl,
        const MediaCacheImageLoadException(failedUrl),
      );

      expect(AvatarFailureCache.instance.isFailed(failedUrl), isTrue);
    });

    testWidgets(
      'caches a broken raster URL through the real image provider',
      (tester) async {
        const brokenUrl = 'https://blotcdn.com/dead-avatar.png';
        final cache = _MockMediaCacheManager();
        when(
          () => cache.getFileFromCache(any()),
        ).thenAnswer((_) async => null);
        when(
          () => cache.cacheFileCancellable(
            any(),
            key: any(named: 'key'),
            aliasKey: any(named: 'aliasKey'),
            authHeaders: any(named: 'authHeaders'),
          ),
          // An empty stream resolves the download to a null file — exactly
          // what a dead URL (non-2xx / DNS failure) produces in production.
        ).thenReturn(
          CancellableCacheOperation.fromStream(
            const Stream<FileResponse>.empty(),
          ),
        );
        debugImageCacheOverride = cache;
        addTearDown(() => debugImageCacheOverride = null);

        await tester.pumpWidget(buildAvatar(imageUrl: brokenUrl));
        await tester.pumpAndSettle();

        expect(AvatarFailureCache.instance.isFailed(brokenUrl), isTrue);
      },
    );

    testWidgets('keeps raster avatar URLs on VineCachedImage', (tester) async {
      await tester.pumpWidget(
        buildAvatar(imageUrl: 'https://divine.video/avatar.png'),
      );

      expect(find.byType(VineCachedImage), findsOneWidget);
    });

    testWidgets('renders direct image providers without network widgets', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserAvatar(
              imageProvider: MemoryImage(_transparentImageBytes),
              name: 'Test User',
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(VineCachedImage), findsNothing);
    });
  });
}

class _ValidSvgHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _ValidSvgRequest();

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _ValidSvgRequest();

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ValidSvgRequest implements HttpClientRequest {
  final _headers = _EmptyHttpHeaders();

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = false;

  @override
  int contentLength = 0;

  @override
  HttpHeaders get headers => _headers;

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  Future<HttpClientResponse> close() async => _ValidSvgResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ValidSvgResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _ValidSvgResponse()
    : _body = utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1" />',
      );

  final List<int> _body;
  final _headers = _EmptyHttpHeaders();

  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _body.length;

  @override
  bool get persistentConnection => false;

  @override
  HttpHeaders get headers => _headers;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  String get reasonPhrase => 'OK';

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_body).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyHttpHeaders implements HttpHeaders {
  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
