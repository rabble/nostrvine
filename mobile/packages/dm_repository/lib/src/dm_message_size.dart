// ABOUTME: Size ceiling for a NIP-17 message body, derived from the NIP-44
// ABOUTME: u16 length prefix and the double encryption NIP-17 performs.

/// How large a NIP-17 message body may be before the send is refused.
///
/// ## Where the hard ceiling comes from
///
/// NIP-44 v2 defines two length-prefix forms, but this client writes only the
/// 2-byte `u16` (see `NIP44V2.pad`), so it cannot encrypt a plaintext of
/// 65,536 bytes or more. NIP-17 then encrypts **twice**: the seal encrypts the
/// rumor, and the gift wrap encrypts the whole seal *event JSON*, whose
/// `content` is the seal's base64 payload. Base64 costs 4/3, so the outer
/// encrypt meets the u16 wall long before the inner one does.
///
/// Measured against the production wrap builder rather than derived: a 1:1
/// kind-14 send with a single `p` tag succeeds at 40,682 bytes of content and
/// throws at 40,683, and no larger size fits — `calcPaddedLen` jumps the inner
/// padded size from 40,960 to 49,152 at that boundary, which alone pushes the
/// outer plaintext past 65,535 (#7331).
///
/// ## Why this constant is well below that
///
/// 40,682 is the ceiling for the *smallest possible* rumor. Every additional
/// `p` tag on a group rumor, and any reply or subject tag, enlarges the sealed
/// JSON and lowers the real ceiling, so a limit set at the 1:1 maximum would
/// still fail for a group send. 32 KiB leaves roughly 7,900 bytes of headroom —
/// on the order of a hundred extra recipients — while staying far above any
/// message a person composes.
///
/// ## Why bytes rather than characters
///
/// The composer's `maxLength` truncates by grapheme cluster, and one cluster
/// can be many bytes (a ZWJ emoji sequence runs past 25). A character limit is
/// a useful affordance but not a bound, so the byte check here is what actually
/// prevents the failure.
const int maxDmMessageContentBytes = 32 * 1024;
