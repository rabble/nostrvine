/// Outcome of an attempt to create viewer-auth headers for a media GET.
///
/// Replaces a bare `Map<String, String>?` so the age-gate UI can tell a signer
/// timeout apart from every other "no headers" case: the remedies differ
/// (check the connection vs. re-verify), so they need distinct copy.
sealed class ViewerAuthResult {
  const ViewerAuthResult();

  /// The created headers, or null for any non-authorized outcome. Lets callers
  /// that only need the headers (e.g. the prefetch/cache path) ignore the
  /// outcome distinction.
  Map<String, String>? get headersOrNull => switch (this) {
    ViewerAuthAuthorized(:final headers) => headers,
    ViewerAuthSignerUnreachable() => null,
    ViewerAuthBlockedByPreference() => null,
    ViewerAuthUnavailable() => null,
  };
}

/// Viewer-auth headers were created successfully.
class ViewerAuthAuthorized extends ViewerAuthResult {
  const ViewerAuthAuthorized(this.headers);

  final Map<String, String> headers;
}

/// A non-interactive remote signer (Keycast OAuth, no local key) did not respond
/// within the signing timeout. The remedy is checking connectivity, not
/// re-verifying age — so this surfaces its own user-facing message.
class ViewerAuthSignerUnreachable extends ViewerAuthResult {
  const ViewerAuthSignerUnreachable();
}

/// The viewer is age-verified but their Content Filters keep adult content
/// hidden. The remedy is opting in via Settings → Content Filters, not
/// re-verifying age — so this surfaces its own user-facing message.
class ViewerAuthBlockedByPreference extends ViewerAuthResult {
  const ViewerAuthBlockedByPreference();
}

/// No viewer-auth headers could be created for any other reason: the user is not
/// authenticated, the signature came back empty, the request shape is
/// unsupported, or the viewer declined/was blocked upstream.
class ViewerAuthUnavailable extends ViewerAuthResult {
  const ViewerAuthUnavailable();
}
