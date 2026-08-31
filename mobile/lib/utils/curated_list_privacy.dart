// ABOUTME: Defines the visibility invariant for curated lists.
// ABOUTME: Keeps private lists owner-only by forbidding collaboration.

/// Whether a curated list's visibility and collaboration settings can coexist.
bool hasValidCuratedListVisibility(bool isPublic, bool isCollaborative) =>
    isPublic || !isCollaborative;
