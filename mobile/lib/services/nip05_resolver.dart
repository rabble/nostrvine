// ABOUTME: Discriminated NIP-05 resolver for the protected-minor DM restriction
// ABOUTME: (#176). Unlike Nip05Validor (collapses everything to null), it separates
// ABOUTME: matched / differentKey / absent / networkError so revocation can be graded.

import 'dart:convert';

import 'package:dio/dio.dart';

/// How a NIP-05 resolution landed, graded by ambiguity so the caller can react
/// differently: a different key is an unambiguous revoke/compromise (drop now),
/// an affirmative absence is softer (confirm before dropping), and a network
/// failure carries no signal at all (keep last-known).
enum Nip05ResolutionKind { matched, differentKey, absent, networkError }

/// The outcome of resolving one NIP-05 identifier against an expected pubkey.
class Nip05Resolution {
  final Nip05ResolutionKind kind;

  /// The pubkey the name server returned, for `matched` and `differentKey`.
  /// Null for `absent` and `networkError`.
  final String? resolvedPubkey;

  const Nip05Resolution._(this.kind, this.resolvedPubkey);

  const Nip05Resolution.matched(String pubkey)
    : this._(Nip05ResolutionKind.matched, pubkey);
  const Nip05Resolution.differentKey(String pubkey)
    : this._(Nip05ResolutionKind.differentKey, pubkey);
  const Nip05Resolution.absent() : this._(Nip05ResolutionKind.absent, null);
  const Nip05Resolution.networkError()
    : this._(Nip05ResolutionKind.networkError, null);
}

/// Whether the name server produced a usable directory answer, before any
/// per-caller expected-key comparison. Shared across concurrent callers so a
/// single fetch classifies against each caller's own expected pubkey.
enum _RawKind { found, absent, networkError }

class _RawResolution {
  final _RawKind kind;
  final String? pubkey;
  const _RawResolution(this.kind, [this.pubkey]);
}

class Nip05Resolver {
  /// A legitimate nostr.json for a handful of names is well under a kilobyte.
  /// NOTE: with Dio's default buffering adapter the body is already downloaded
  /// by the time we read the header, so this check is a parse-guard (skip
  /// decoding an absurd body), NOT a memory bound. The real bound against a
  /// slow/huge/chunked body from a hostile or MITM'd origin is `receiveTimeout`.
  /// A true byte cap would require a streamed read; deliberately not done for a
  /// tiny, Divine-controlled HTTPS endpoint where a resolver failure fails the
  /// send closed rather than opening a channel.
  static const int _maxContentLength = 256 * 1024;

  final Dio _dio;

  /// De-dups concurrent fetches for the same identifier. Keyed by the
  /// normalized `name@domain`; callers await the same underlying fetch and get
  /// its real result (never a null-as-failure that would degrade send-time
  /// freshness to fail-open).
  final Map<String, Future<_RawResolution>> _inFlight = {};

  Nip05Resolver({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
              followRedirects: true,
              maxRedirects: 3,
            ),
          );

  Future<Nip05Resolution> resolve(
    String nip05Address,
    String expectedPubkey,
  ) async {
    final parsed = _split(nip05Address);
    final name = parsed.$1;
    final domain = parsed.$2;
    final key = '$name@$domain';

    final raw = await (_inFlight[key] ??= _fetchRaw(
      name,
      domain,
    )).whenComplete(() => _inFlight.remove(key));

    switch (raw.kind) {
      case _RawKind.networkError:
        return const Nip05Resolution.networkError();
      case _RawKind.absent:
        return const Nip05Resolution.absent();
      case _RawKind.found:
        final resolved = raw.pubkey!.trim();
        // Normalize BOTH sides identically: the pin is the trust anchor, and a
        // checksummed/padded nostr.json must not read as a different key and
        // spuriously revoke a live account.
        if (resolved.toLowerCase() == expectedPubkey.trim().toLowerCase()) {
          return Nip05Resolution.matched(resolved);
        }
        return Nip05Resolution.differentKey(resolved);
    }
  }

  /// Fetches and classifies the directory answer for one identifier, without
  /// the per-caller expected-key comparison (that stays in [resolve] so one
  /// fetch can serve callers checking different keys).
  Future<_RawResolution> _fetchRaw(String name, String domain) async {
    final Object? data;
    try {
      final res = await _dio.get(
        'https://$domain/.well-known/nostr.json?name=$name',
      );
      // Parse-guard only (see _maxContentLength): avoids decoding an absurd
      // advertised body; the download has already happened by here.
      final advertised = int.tryParse(
        res.headers.value('content-length') ?? '',
      );
      if (advertised != null && advertised > _maxContentLength) {
        return const _RawResolution(_RawKind.networkError);
      }
      data = res.data;
    } on DioException catch (e) {
      // A 404 is an affirmative "this name is not here"; anything else
      // (timeout, offline, 5xx, connection reset) carries no signal.
      if (e.response?.statusCode == 404) {
        return const _RawResolution(_RawKind.absent);
      }
      return const _RawResolution(_RawKind.networkError);
    } catch (_) {
      return const _RawResolution(_RawKind.networkError);
    }

    final Object? map;
    try {
      map = data is String ? jsonDecode(data) : data;
    } catch (_) {
      // Not JSON at all -> malformed, no trustworthy signal.
      return const _RawResolution(_RawKind.networkError);
    }

    // A well-formed nostr.json MUST carry a `names` object. Its absence means
    // the response isn't a usable directory (malformed), not that the name was
    // affirmatively withdrawn.
    if (map is! Map || map['names'] is! Map) {
      return const _RawResolution(_RawKind.networkError);
    }

    final resolved = (map['names'] as Map)[name];
    if (resolved is! String) {
      // Well-formed directory that simply does not list this name.
      return const _RawResolution(_RawKind.absent);
    }
    return _RawResolution(_RawKind.found, resolved);
  }

  /// Splits `name@domain` into `(name, domain)`, defaulting name to `_`, and
  /// normalizes to lowercase/trimmed so a checksummed or spaced identifier
  /// resolves against the same origin.
  (String, String) _split(String nip05Address) {
    final addr = nip05Address.trim().toLowerCase();
    final parts = addr.split('@');
    if (parts.length > 1) {
      return (parts[0], parts[1]);
    }
    return ('_', addr);
  }
}
