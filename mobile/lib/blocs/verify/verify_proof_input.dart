// ABOUTME: Turns a pasted post URL into the identity and proof id the
// ABOUTME: verifier expects, mirroring what the verifier's web form does.

import 'package:meta/meta.dart';

/// A link that cannot become a claim, recognised before the verifier sees it.
enum VerifyProofProblem {
  /// A Telegram link the verifier can never read: a private channel's
  /// `t.me/c/…` message, or an invite rather than a message.
  ///
  /// Verification fetches `t.me/<channel>/<id>` as a public page, so a channel
  /// without a public link has nothing to fetch. Telegram makes new channels
  /// private, which is exactly the state someone is in right after creating
  /// one to hold their proof.
  telegramNotPublic,
}

/// An account handle and proof value ready for the verifier.
@immutable
class VerifyProofInput {
  /// Creates a [VerifyProofInput].
  const VerifyProofInput({
    required this.identity,
    required this.proof,
    this.problem,
  });

  /// Account handle or id on the platform.
  final String identity;

  /// Proof value — usually a post id, not a URL.
  final String proof;

  /// Set when the input is recognisably unusable, so the flow can say why
  /// instead of letting the verifier answer with a generic "not found".
  final VerifyProofProblem? problem;

  @override
  bool operator ==(Object other) =>
      other is VerifyProofInput &&
      other.identity == identity &&
      other.proof == proof &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(identity, proof, problem);

  @override
  String toString() => 'VerifyProofInput($identity, $proof, $problem)';
}

/// Normalizes what the user typed into what the verifier accepts.
///
/// Most platform verifiers rebuild the post URL themselves from the handle
/// and a bare id — `https://x.com/{identity}/status/{proof}`, for example — so
/// a pasted link has to be taken apart first or the lookup 404s. The verifier's
/// own web form does exactly this before it posts, and the service does not
/// repeat it server-side, so a client that skips this step is the one that
/// breaks.
///
/// A pasted link also carries the handle, so [identity] is filled in from the
/// URL when the user left it blank.
///
/// Discord is deliberately untouched: its verifier parses full message URLs
/// itself, and its message ids are only meaningful with their channel.
VerifyProofInput normalizeVerifyProof({
  required String platform,
  required String identity,
  required String proof,
}) {
  final trimmedIdentity = _stripHandlePrefix(platform, identity.trim());
  final trimmedProof = proof.trim();
  if (platform.toLowerCase() == 'discord') {
    return VerifyProofInput(identity: trimmedIdentity, proof: trimmedProof);
  }

  final fromProof = _parse(platform, trimmedProof);
  if (fromProof != null) {
    if (fromProof.problem != null) return fromProof;
    return VerifyProofInput(
      identity: trimmedIdentity.isEmpty ? fromProof.identity : trimmedIdentity,
      proof: fromProof.proof.isEmpty ? trimmedProof : fromProof.proof,
    );
  }

  // Someone who pastes the link into the handle field and leaves the proof
  // empty means the same thing.
  if (trimmedProof.isEmpty) {
    final fromIdentity = _parse(platform, trimmedIdentity);
    if (fromIdentity != null &&
        (fromIdentity.problem != null || fromIdentity.proof.isNotEmpty)) {
      return fromIdentity;
    }
  }

  return VerifyProofInput(identity: trimmedIdentity, proof: trimmedProof);
}

VerifyProofInput? _parse(String platform, String raw) {
  final uri = _tryParseUrl(raw);
  if (uri == null) return null;

  final host = uri.host.toLowerCase();
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

  switch (platform.toLowerCase()) {
    case 'github':
      if (host.endsWith('gist.github.com') && segments.length >= 2) {
        return VerifyProofInput(identity: segments[0], proof: segments[1]);
      }
    case 'twitter':
      if (_isTwitterHost(host)) {
        final index = segments.indexOf('status');
        if (index > 0 && index + 1 < segments.length) {
          return VerifyProofInput(
            identity: segments[index - 1].replaceFirst(RegExp('^@'), ''),
            proof: segments[index + 1],
          );
        }
      }
    case 'bluesky':
      if (host == 'bsky.app' &&
          segments.length >= 4 &&
          segments[0] == 'profile' &&
          segments[2] == 'post') {
        return VerifyProofInput(identity: segments[1], proof: segments[3]);
      }
    case 'mastodon':
      // The instance is part of the identity, so any host can be the right
      // one — the shape of the path is what identifies a status.
      if (segments.length >= 2 && segments[0].startsWith('@')) {
        return VerifyProofInput(
          identity: '$host/${segments[0]}',
          proof: segments[1],
        );
      }
      if (segments.length >= 4 &&
          segments[0] == 'users' &&
          segments[2] == 'statuses') {
        return VerifyProofInput(
          identity: '$host/@${segments[1]}',
          proof: segments[3],
        );
      }
    case 'telegram':
      if (host != 't.me' && host != 'www.t.me') return null;
      // `t.me/c/<internal id>/<message>` is a private channel's link, and
      // `t.me/+code` / `t.me/joinchat/code` are invites. Neither resolves to a
      // page the verifier can read, and both are what Telegram hands you for a
      // freshly created channel.
      if (segments.isEmpty ||
          segments[0] == 'c' ||
          segments[0] == 'joinchat' ||
          segments[0].startsWith('+')) {
        return const VerifyProofInput(
          identity: '',
          proof: '',
          problem: VerifyProofProblem.telegramNotPublic,
        );
      }
      // `t.me/s/<channel>/<id>` is the web-preview spelling of a public
      // message; the verifier wants it without the `s`.
      final path = segments[0] == 's' ? segments.sublist(1) : segments;
      if (path.length >= 2) {
        final channel = path[0].replaceFirst(RegExp('^@'), '');
        return VerifyProofInput(
          identity: channel,
          proof: '$channel/${path[1]}',
        );
      }
    case 'youtube':
      if (host.endsWith('youtube.com')) {
        final videoId = uri.queryParameters['v'];
        if (videoId != null && videoId.isNotEmpty) {
          return VerifyProofInput(identity: '', proof: videoId);
        }
        if (segments.length >= 2 && segments[0] == 'shorts') {
          return VerifyProofInput(identity: '', proof: segments[1]);
        }
      }
      if (host.endsWith('youtu.be') && segments.isNotEmpty) {
        return VerifyProofInput(identity: '', proof: segments[0]);
      }
    case 'tiktok':
      if (host.endsWith('tiktok.com')) {
        final index = segments.indexOf('video');
        if (index != -1 && index + 1 < segments.length) {
          final handle = segments.firstWhere(
            (s) => s.startsWith('@'),
            orElse: () => '',
          );
          return VerifyProofInput(
            identity: handle.isEmpty ? '' : handle.substring(1),
            proof: segments[index + 1],
          );
        }
      }
  }
  return null;
}

/// Drops a leading `@` from a typed handle.
///
/// Every verifier that matches a handle compares it to what the platform
/// reports, and none of them report the `@` — a typed `@testdivine` fails as
/// "author does not match" against an author named `testdivine`. Mastodon is
/// left alone: its handle is `instance/@user`, where the `@` is structural.
String _stripHandlePrefix(String platform, String identity) {
  if (platform.toLowerCase() == 'mastodon') return identity;
  return identity.startsWith('@') ? identity.substring(1) : identity;
}

bool _isTwitterHost(String host) =>
    host == 'x.com' ||
    host == 'www.x.com' ||
    host == 'twitter.com' ||
    host == 'www.twitter.com';

final _bareHostPattern = RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/.+');

Uri? _tryParseUrl(String raw) {
  if (raw.isEmpty) return null;
  final parsed = Uri.tryParse(raw);
  if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
    return parsed;
  }
  // People paste "x.com/jack/status/1" as often as the full link.
  if (_bareHostPattern.hasMatch(raw)) {
    return Uri.tryParse('https://$raw');
  }
  return null;
}
