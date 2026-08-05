// ABOUTME: Port resolving a video event id to its sibling NIP-33 revisions.
// ABOUTME: Injected so this package needs no API-client dependency.

/// Resolves video event ids to every event id sharing their NIP-33 coordinate.
///
/// Editing an addressable video (kind 34235/34236) preserves the coordinate
/// `kind:pubkey:d-tag` but mints a **new event id**. NIP-25 requires a kind 7
/// reaction to carry an `e` tag and only *recommends* the `a` tag, so a
/// reaction may name one concrete revision and nothing else. After an edit,
/// such a reaction matches neither the current event id nor the coordinate,
/// and disappears from the "Liked by" list even though funnelcake's
/// coordinate-keyed aggregate still counts it (divinevideo/divine-mobile#6021).
///
/// A client cannot derive these ids on its own: a coordinate-shaped relay REQ
/// returns only the latest revision, an `until` walk returns nothing because
/// the coordinate is collapsed before `until` is applied, and the local event
/// cache deletes older revisions on upsert. They have to come from a source
/// that retains every revision.
///
/// Implementations receive the event ids to resolve and return a map of
/// `eventId -> revisionIds`, where the list includes the requested id itself.
/// Ids that resolve to no addressable video may be omitted.
///
/// Implementations must not throw or hang: degrade instead, so callers fall
/// back to querying the current id alone rather than failing the whole list.
/// Degrade in whichever of the two shapes is true, because callers cache the
/// answer for the session:
///
/// * An empty map means the source answered and has no revisions to add.
/// * `null` means the source could not answer — it failed, or is not
///   configured — and the same call may succeed later.
///
/// Repository callers also bound this resolver with a short timeout because
/// revision data is additive, not a precondition for showing current-id
/// likers.
typedef VideoRevisionsResolver =
    Future<Map<String, List<String>>?> Function(List<String> eventIds);
