// ABOUTME: Product thresholds for how profile engagement metrics are shown.
// ABOUTME: Shared by the profile header and the message-request preview.

/// Smallest lifetime loop total a profile shows to visitors.
///
/// Below this the Loops figure is omitted for everyone but the owner: a small
/// headline number on a new creator's profile discourages the visitor and
/// tells them nothing useful. Owners always see their own total, since
/// correcting a creator's underestimate of their audience is what keeps them
/// posting.
///
/// A product call, not a technical one — the single value to change if the
/// bar sits wrong.
///
/// Deliberately higher than `publicLoopCountFloor` in
/// `widgets/video_feed_item/video_card_meta.dart`, which hides small counts on
/// feed cards. A profile headline is a summary of a whole creator and carries
/// more weight than a number beside one video, so it earns a higher bar. The
/// two are independent product calls, not a value that drifted — do not
/// collapse them into one constant without deciding that both surfaces want
/// the same number.
///
/// Lives here rather than beside one consumer because it now has two: the
/// profile header's Loops column, and the message-request preview's stats
/// line. On the preview the sender is never the viewer, so there is no
/// owner exemption there — the floor always applies.
const int profileLoopsVisibilityFloor = 10000;
