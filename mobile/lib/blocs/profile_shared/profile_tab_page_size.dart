// ABOUTME: Shared page size for the cached profile tab grids
// ABOUTME: Sized so one page covers about two viewports of a 3-column grid

/// Items fetched per page by the Liked / Reposts / Saved / Collabs tabs.
///
/// These tabs render a 3-column square grid, so a phone viewport shows
/// roughly six rows — about 18 items. A page must cover clearly more than
/// one viewport: `ScrollPaginationMixin` requests the next page 1.5
/// viewports before the bottom, so a one-viewport page would leave the grid
/// permanently mid-fetch and keep the loading-more spinner in view. Twelve
/// rows gives the prefetch enough headroom to land before the user gets
/// there.
const profileTabPageSize = 36;
