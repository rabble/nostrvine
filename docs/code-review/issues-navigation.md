# Navigation Issues

Issues related to routing, deep linking, and navigation patterns.

Note: GoRouter handles 60+ routes with deep linking and `pushWithVideoPause` manages video playback state during transitions. These 2 issues cover the gap between current procedural route definitions and the type-safe `@TypedGoRoute` approach the project's own rules recommend, plus unvalidated deep link parameters.

---

### GoRouter uses procedural route definitions
**Problem**: Manual string-based paths in `app_router.dart` (1,117 lines) instead of `@TypedGoRoute` code generation recommended by the project's own routing rules.

**Evidence**: `app_router.dart` (1,117 lines) uses manual string-based path definitions with inline route builders, importing 60+ screen files directly. Route paths defined as static constants on screen classes (`WelcomeScreen.path`, `ExploreScreen.routeName`). `route_extras.dart` defines `CuratedListRouteExtra` and `VideoEditorRouteExtra`, objects passed via GoRouter's `extra` parameter (the architecture rules say "Don't use extra for passing objects: breaks deep linking and web"). The project's own `.claude/rules/routing.md` recommends `@TypedGoRoute` for type-safe routing with compile-time parameter validation.

**Impact**: Medium. Hardcoded path strings break silently on refactoring; no compile-time route parameter validation; screen coupling to routing forces 60+ imports in the router file; `extra` usage breaks deep linking.

**Effort**: High. Migrating all routes to `@TypedGoRoute` requires adding route data classes for each route, running code generation, and updating all navigation call sites across the app. Best done incrementally: adopt `@TypedGoRoute` for new routes, migrate existing routes when touched.

**GitHub ticket**: TBD

---

### Deep link parameters not validated before navigation
**Problem**: Deep link parameters (video IDs, npub values, hashtags, search terms) are used for navigation without format validation.

**Evidence**: `mobile/lib/main.dart` lines 1119–1286: deep link handler passes parameters directly to router with only null checks, no format validation. Video IDs are not checked for valid hex format, npub values are not validated as bech32, and search terms from deep links are passed to API queries without sanitization.

**Impact**: Low. GoRouter's built-in URL handling provides some protection. The risk is primarily malformed data causing crashes or unexpected behavior in downstream screens.

**Effort**: Low. Add format validation before navigation (regex check for hex video IDs, bech32 validation for npub).

**GitHub ticket**: TBD
