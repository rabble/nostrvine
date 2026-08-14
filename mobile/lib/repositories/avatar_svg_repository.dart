// ABOUTME: Validates remote avatar SVG payloads before flutter_svg sees them.
// ABOUTME: Prevents malformed profile-picture markup from surfacing as zone errors.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:unified_logger/unified_logger.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

abstract class AvatarSvgRepository {
  /// Loads and validates a remote avatar SVG.
  ///
  /// Returns `null` for expected remote-data failures: malformed URLs,
  /// non-200 responses, oversized responses, non-SVG payloads, malformed XML,
  /// or network failures. Callers should render the normal avatar placeholder
  /// for `null`.
  Future<Uint8List?> load(String url);
}

class AvatarSvgRepositoryConfig {
  const AvatarSvgRepositoryConfig._();

  static const int maxBytes = 256 * 1024;
  static const int maxCacheEntries = 128;
  static const Duration requestTimeout = Duration(seconds: 5);
  static const Duration positiveTtl = Duration(hours: 1);
  static const Duration negativeTtl = Duration(minutes: 10);
}

typedef AvatarSvgClock = DateTime Function();

class HttpAvatarSvgRepository implements AvatarSvgRepository {
  HttpAvatarSvgRepository({
    http.Client? client,
    AvatarSvgClock clock = DateTime.now,
    Duration requestTimeout = AvatarSvgRepositoryConfig.requestTimeout,
  }) : _client = client ?? http.Client(),
       _clock = clock,
       _requestTimeout = requestTimeout;

  final http.Client _client;
  final AvatarSvgClock _clock;
  final Duration _requestTimeout;
  final _cache = <String, _AvatarSvgCacheEntry>{};
  final _inFlight = <String, Future<Uint8List?>>{};

  @override
  Future<Uint8List?> load(String url) async {
    final cached = _readCache(url);
    if (cached != null) return cached.bytes;

    final inFlight = _inFlight[url];
    if (inFlight != null) return inFlight;

    final pending = _loadUncached(url);
    _inFlight[url] = pending;
    return pending.whenComplete(() => _inFlight.remove(url));
  }

  Future<Uint8List?> _loadUncached(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      _writeCache(url, null, AvatarSvgRepositoryConfig.negativeTtl);
      return null;
    }

    try {
      final bytes = await _fetch(uri);
      _writeCache(
        url,
        bytes,
        bytes == null
            ? AvatarSvgRepositoryConfig.negativeTtl
            : AvatarSvgRepositoryConfig.positiveTtl,
      );
      return bytes;
    } on Object catch (error) {
      UnifiedLogger.warning(
        'Avatar SVG validation failed for URL: $url - Error: $error',
        name: 'AvatarSvgRepository',
      );
      _writeCache(url, null, AvatarSvgRepositoryConfig.negativeTtl);
      return null;
    }
  }

  Future<Uint8List?> _fetch(Uri uri) async {
    final request = http.Request('GET', uri)
      ..headers['accept'] = 'image/svg+xml,image/*;q=0.8,*/*;q=0.1';
    final response = await _client.send(request).timeout(_requestTimeout);

    if (response.statusCode != 200) {
      await _cancelResponseBody(response.stream);
      _logRejected(uri, response.headers['content-type'], 'status');
      return null;
    }

    final bytes = await _readBounded(response.stream);
    if (bytes == null) {
      _logRejected(uri, response.headers['content-type'], 'oversized');
      return null;
    }

    final contentType = response.headers['content-type'];
    if (!_hasSvgContentType(contentType) && !_startsLikeSvg(bytes)) {
      _logRejected(uri, contentType, 'non-svg-payload');
      return null;
    }

    if (!_parsesAsSvg(bytes)) {
      _logRejected(uri, contentType, 'malformed-svg');
      return null;
    }

    return bytes;
  }

  Future<Uint8List?> _readBounded(Stream<List<int>> stream) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in _withBodyTimeout(stream)) {
      builder.add(chunk);
      if (builder.length > AvatarSvgRepositoryConfig.maxBytes) {
        return null;
      }
    }
    return builder.takeBytes();
  }

  Stream<List<int>> _withBodyTimeout(Stream<List<int>> stream) {
    return stream.timeout(
      _requestTimeout,
      onTimeout: (sink) {
        sink.addError(
          TimeoutException('Avatar SVG body read timed out', _requestTimeout),
        );
        sink.close();
      },
    );
  }

  Future<void> _cancelResponseBody(Stream<List<int>> stream) async {
    final subscription = stream.listen(null, onError: (_, _) {});
    try {
      await subscription.cancel().timeout(_requestTimeout);
    } on Object catch (error) {
      UnifiedLogger.debug(
        'Avatar SVG response body cancel failed: $error',
        name: 'AvatarSvgRepository',
      );
    }
  }

  bool _hasSvgContentType(String? contentType) =>
      contentType?.toLowerCase().trim().startsWith('image/svg+xml') ?? false;

  bool _startsLikeSvg(Uint8List bytes) {
    var index = 0;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      index = 3;
    }
    while (index < bytes.length && _isAsciiWhitespace(bytes[index])) {
      index++;
    }
    final remaining = utf8.decode(
      bytes.skip(index).take(16).toList(),
      allowMalformed: true,
    );
    return remaining.startsWith('<svg') || remaining.startsWith('<?xml');
  }

  bool _isAsciiWhitespace(int byte) =>
      byte == 0x09 || byte == 0x0A || byte == 0x0D || byte == 0x20;

  /// Whether [bytes] survive the exact XML pass `flutter_svg` performs, with
  /// `svg` as the root element.
  ///
  /// This mirrors the consumer deliberately: `SvgBytesLoader.provideSvg`
  /// decodes with `allowMalformed: true`, and `SvgParser` tokenizes with
  /// `parseEvents` and no nesting or document validation. A stricter check
  /// rejects avatars flutter_svg renders fine; a laxer one lets a parse
  /// failure reach flutter_svg, where the call site can no longer catch it —
  /// `Cache.putIfAbsent` hangs a success-only `then` on the decode future and
  /// drops the derived future, so the failure also surfaces as an unhandled
  /// zone error and a Crashlytics non-fatal, even though `errorBuilder`
  /// already renders the placeholder (#7296).
  ///
  /// [parseEvents] is lazy, so the events have to be drained here. Stopping at
  /// the root element would report malformed markup further down the document
  /// as valid and hand the failure back to flutter_svg.
  ///
  /// Beyond tokenizing, this enforces one document-level rule: no end element
  /// may sit outside the root. `SvgParser.endElement` reads
  /// `_parentDrawables.last` with no empty check, so such an element throws
  /// `StateError: No element` there.
  ///
  /// The rule is expressed over the document rather than over flutter_svg's
  /// own stack on purpose. Mirroring that stack would mean mirroring its push
  /// rule too — only `addGroup` pushes, so a `rect` left open desynchronises
  /// the two — and the push set is `vector_graphics_compiler` internals that a
  /// version bump can move underneath us.
  ///
  /// Tracking the root by `svg` nesting depth is what keeps a nested `<svg>`
  /// working, since its own end tag must not be mistaken for the root's.
  /// Unbalanced markup *inside* the root stays accepted: it trips only a debug
  /// `assert` in the compiler and renders in release.
  ///
  /// The rule is one-directional, though: `endElement` pops only on a name
  /// match, so an `</svg>` arriving while a group is open never empties
  /// `_parentDrawables`. `<svg><g><rect/></svg></g>` renders there and is
  /// rejected here — the price of not coupling to the push set.
  bool _parsesAsSvg(Uint8List bytes) {
    final source = utf8.decode(bytes, allowMalformed: true);
    String? rootName;
    var svgDepth = 0;
    var rootClosed = false;
    try {
      for (final event in parseEvents(source)) {
        if (event is XmlStartElementEvent) {
          rootName ??= event.localName;
          if (_isSvgTag(event.localName) && !event.isSelfClosing) svgDepth++;
        } else if (event is XmlEndElementEvent) {
          if (rootName == null || rootClosed) return false;
          if (_isSvgTag(event.localName)) {
            svgDepth--;
            if (svgDepth <= 0) rootClosed = true;
          }
        }
      }
    } on XmlException {
      return false;
    }
    return rootName != null && _isSvgTag(rootName);
  }

  bool _isSvgTag(String localName) => localName.toLowerCase() == 'svg';

  _AvatarSvgCacheEntry? _readCache(String url) {
    final cached = _cache.remove(url);
    if (cached == null) return null;
    if (!_clock().isBefore(cached.expiresAt)) return null;
    _cache[url] = cached;
    return cached;
  }

  void _writeCache(String url, Uint8List? bytes, Duration ttl) {
    if (url.isEmpty || ttl <= Duration.zero) return;
    _cache.remove(url);
    _cache[url] = _AvatarSvgCacheEntry(
      bytes: bytes,
      expiresAt: _clock().add(ttl),
    );

    while (_cache.length > AvatarSvgRepositoryConfig.maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  void _logRejected(Uri uri, String? contentType, String reason) {
    UnifiedLogger.warning(
      'Avatar SVG rejected: url=$uri contentType=${contentType ?? '<none>'} reason=$reason',
      name: 'AvatarSvgRepository',
    );
  }
}

class _AvatarSvgCacheEntry {
  const _AvatarSvgCacheEntry({required this.bytes, required this.expiresAt});

  final Uint8List? bytes;
  final DateTime expiresAt;
}

final AvatarSvgRepository defaultAvatarSvgRepository =
    HttpAvatarSvgRepository();
