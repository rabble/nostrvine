# Vetted Nostr App Sandbox Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Cloudflare-backed vetted app directory plus a Divine mobile sandbox that injects a narrow `window.nostr` bridge for approved third-party Nostr apps on allowlisted origins.

**Architecture:** Keep Cloudflare as the single source of truth for approved app manifests and audit visibility, while Divine mobile remains the only component with signing authority. Add isolated Cloudflare packages under `website/` for the directory worker and admin UI, then add a dedicated mobile app directory flow, sandbox browser, capability policy, remembered grants, and sanitized audit uploads.

**Tech Stack:** Flutter, Riverpod, GoRouter, `webview_flutter`, Divine auth/signing services, existing `Nip98AuthService`, Cloudflare Worker, D1, Cloudflare Access, vanilla JS admin UI, npm, Vitest.

---

## File Map

- Create: `website/apps-directory-worker/package.json`
  Purpose: isolated Cloudflare worker package for app directory and audit APIs.
- Create: `website/apps-directory-worker/wrangler.toml`
  Purpose: worker bindings, D1 config, route setup.
- Create: `website/apps-directory-worker/schema.sql`
  Purpose: D1 schema for manifests and audit events.
- Create: `website/apps-directory-worker/src/index.ts`
  Purpose: Worker entry point and route wiring.
- Create: `website/apps-directory-worker/src/lib/env.ts`
  Purpose: typed bindings and env helpers.
- Create: `website/apps-directory-worker/src/lib/manifest-schema.ts`
  Purpose: manifest validation and sanitization.
- Create: `website/apps-directory-worker/src/lib/manifest-store.ts`
  Purpose: D1 persistence for app manifests.
- Create: `website/apps-directory-worker/src/lib/audit-store.ts`
  Purpose: D1 persistence for audit events.
- Create: `website/apps-directory-worker/src/lib/nip98.ts`
  Purpose: NIP-98 verification for mobile audit uploads.
- Create: `website/apps-directory-worker/test/manifest-schema.test.ts`
  Purpose: validation coverage.
- Create: `website/apps-directory-worker/test/routes.test.ts`
  Purpose: public/admin/audit route coverage.
- Create: `website/apps-admin/package.json`
  Purpose: isolated admin frontend package.
- Create: `website/apps-admin/index.html`
  Purpose: admin shell.
- Create: `website/apps-admin/styles.css`
  Purpose: admin styling.
- Create: `website/apps-admin/src/main.js`
  Purpose: bootstraps admin console.
- Create: `website/apps-admin/src/api.js`
  Purpose: admin API client.
- Create: `website/apps-admin/src/app-form.js`
  Purpose: manifest editor form logic.
- Create: `website/apps-admin/src/app-list.js`
  Purpose: app directory table rendering.
- Create: `website/apps-admin/src/audit-list.js`
  Purpose: audit viewer rendering.
- Create: `website/apps-admin/test/app-form.test.js`
  Purpose: manifest form serialization/validation coverage.
- Create: `mobile/lib/models/nostr_app_directory_entry.dart`
  Purpose: typed manifest model consumed by mobile.
- Create: `mobile/lib/models/nostr_app_audit_event.dart`
  Purpose: local audit payload model.
- Create: `mobile/lib/services/nostr_app_directory_service.dart`
  Purpose: fetch and cache approved manifests.
- Create: `mobile/lib/services/nostr_app_grant_store.dart`
  Purpose: persist remembered permissions per user/app/origin/capability.
- Create: `mobile/lib/services/nostr_app_audit_service.dart`
  Purpose: record local audit events and upload sanitized copies with NIP-98.
- Create: `mobile/lib/services/nostr_app_bridge_policy.dart`
  Purpose: centralize manifest + grant + prompt decisions.
- Create: `mobile/lib/services/nostr_app_bridge_service.dart`
  Purpose: execute `window.nostr` requests through native signer services.
- Create: `mobile/lib/screens/apps/apps_directory_screen.dart`
  Purpose: settings-entry directory listing.
- Create: `mobile/lib/screens/apps/app_detail_screen.dart`
  Purpose: app detail and launch surface.
- Create: `mobile/lib/screens/apps/apps_permissions_screen.dart`
  Purpose: manage remembered grants and revoked sandbox permissions.
- Create: `mobile/lib/screens/apps/nostr_app_sandbox_screen.dart`
  Purpose: dedicated WebView sandbox with navigation blocking and JS bridge.
- Create: `mobile/lib/widgets/apps/nostr_app_permission_prompt_sheet.dart`
  Purpose: runtime approval prompt UI.
- Create: `mobile/test/services/nostr_app_directory_service_test.dart`
  Purpose: directory fetch/cache/revocation coverage.
- Create: `mobile/test/services/nostr_app_bridge_policy_test.dart`
  Purpose: grant/prompt policy coverage.
- Create: `mobile/test/services/nostr_app_bridge_service_test.dart`
  Purpose: bridge method and event-kind enforcement coverage.
- Create: `mobile/test/services/nostr_app_audit_service_test.dart`
  Purpose: local + remote audit behavior coverage.
- Create: `mobile/test/screens/apps/apps_directory_screen_test.dart`
  Purpose: directory UI coverage.
- Create: `mobile/test/screens/apps/nostr_app_sandbox_screen_test.dart`
  Purpose: sandbox screen behavior coverage.
- Modify: `mobile/pubspec.yaml`
  Purpose: add `webview_flutter`.
- Modify: `mobile/lib/config/app_config.dart`
  Purpose: add apps directory base URL configuration.
- Modify: `mobile/lib/providers/app_providers.dart`
  Purpose: wire directory, grant, policy, bridge, and audit services.
- Modify: `mobile/lib/router/app_router.dart`
  Purpose: register app directory, detail, and sandbox routes.
- Modify: `mobile/lib/router/providers/page_context_provider.dart`
  Purpose: route context support for new screens.
- Modify: `mobile/lib/screens/settings/settings_screen.dart`
  Purpose: add Apps entry point.
- Modify: `mobile/test/router/all_routes_test.dart`
  Purpose: route coverage for new screens.
- Modify: `mobile/test/router/route_coverage_test.dart`
  Purpose: route coverage for new screens.
- Modify: `mobile/test/widgets/settings_screen_test.dart`
  Purpose: settings entry coverage.

## Chunk 1: Cloudflare Directory Worker

### Task 1: Scaffold the worker package and D1 schema

**Files:**
- Create: `website/apps-directory-worker/package.json`
- Create: `website/apps-directory-worker/wrangler.toml`
- Create: `website/apps-directory-worker/schema.sql`
- Create: `website/apps-directory-worker/src/index.ts`
- Create: `website/apps-directory-worker/src/lib/env.ts`
- Test: `website/apps-directory-worker/test/routes.test.ts`

- [ ] **Step 1: Write the failing route smoke test**

Add a worker test that calls:

```ts
GET /v1/apps
```

and expects a JSON array response shape.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd website/apps-directory-worker && npm install && npm test
```

Expected: FAIL because the package and worker entry point do not exist yet.

- [ ] **Step 3: Create the worker scaffold and schema**

Add:

```ts
export interface Env {
  APPS_DB: D1Database;
  ADMIN_ORIGIN: string;
}
```

and a minimal router:

```ts
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === 'GET' && url.pathname === '/v1/apps') {
      return Response.json({ items: [] });
    }
    return new Response('Not found', { status: 404 });
  },
};
```

Add `schema.sql` with `sandbox_apps` and `sandbox_audit_events`.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd website/apps-directory-worker && npm test
```

Expected: PASS with the basic public route wired.

- [ ] **Step 5: Commit**

```bash
git add website/apps-directory-worker
git commit -m "feat(apps): scaffold directory worker"
```

### Task 2: Add manifest validation and approved-only public endpoints

**Files:**
- Create: `website/apps-directory-worker/src/lib/manifest-schema.ts`
- Create: `website/apps-directory-worker/src/lib/manifest-store.ts`
- Modify: `website/apps-directory-worker/src/index.ts`
- Test: `website/apps-directory-worker/test/manifest-schema.test.ts`
- Test: `website/apps-directory-worker/test/routes.test.ts`

- [ ] **Step 1: Write failing validation tests**

Cover:

```ts
expect(validateManifest({
  slug: 'primal',
  allowed_origins: ['https://primal.net'],
  allowed_methods: ['getPublicKey', 'signEvent'],
  allowed_sign_event_kinds: [1],
  status: 'approved',
})).toBeDefined();
```

and failure cases for empty origins, invalid URL schemes, and unsupported methods.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd website/apps-directory-worker && npm test
```

Expected: FAIL because validation and storage code do not exist.

- [ ] **Step 3: Implement manifest validation and public reads**

Add:

```ts
export const SUPPORTED_METHODS = [
  'getPublicKey',
  'signEvent',
  'nip44.encrypt',
  'nip44.decrypt',
] as const;
```

and public route behavior:

```ts
if (request.method === 'GET' && url.pathname === '/v1/apps') {
  const apps = await manifestStore.listApproved();
  return Response.json({ items: apps });
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
cd website/apps-directory-worker && npm test
```

Expected: PASS with approved-only filtering and schema enforcement.

- [ ] **Step 5: Commit**

```bash
git add website/apps-directory-worker/src website/apps-directory-worker/test
git commit -m "feat(apps): add manifest validation and public directory endpoints"
```

## Chunk 2: Admin Console And Protected Write APIs

### Task 3: Add admin routes protected by Cloudflare Access headers

**Files:**
- Modify: `website/apps-directory-worker/src/index.ts`
- Create: `website/apps-directory-worker/src/lib/admin-auth.ts`
- Modify: `website/apps-directory-worker/src/lib/manifest-store.ts`
- Test: `website/apps-directory-worker/test/routes.test.ts`

- [ ] **Step 1: Write failing admin auth tests**

Add tests for:

```ts
POST /v1/admin/apps
PUT /v1/admin/apps/:id
POST /v1/admin/apps/:id/revoke
```

without Access headers and expect `403`.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd website/apps-directory-worker && npm test
```

Expected: FAIL because admin auth gates do not exist.

- [ ] **Step 3: Implement admin auth and write routes**

Use a helper like:

```ts
export function requireAdmin(request: Request): string {
  const email = request.headers.get('CF-Access-Authenticated-User-Email');
  if (!email) throw new Response('Forbidden', { status: 403 });
  return email;
}
```

and wire CRUD/revoke endpoints.

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
cd website/apps-directory-worker && npm test
```

Expected: PASS with write routes gated by Access identity.

- [ ] **Step 5: Commit**

```bash
git add website/apps-directory-worker/src website/apps-directory-worker/test
git commit -m "feat(apps): add protected admin manifest routes"
```

### Task 4: Build the admin UI

**Files:**
- Create: `website/apps-admin/package.json`
- Create: `website/apps-admin/index.html`
- Create: `website/apps-admin/styles.css`
- Create: `website/apps-admin/src/main.js`
- Create: `website/apps-admin/src/api.js`
- Create: `website/apps-admin/src/app-form.js`
- Create: `website/apps-admin/src/app-list.js`
- Create: `website/apps-admin/src/audit-list.js`
- Test: `website/apps-admin/test/app-form.test.js`

- [ ] **Step 1: Write the failing manifest form serializer test**

Cover serialization:

```js
expect(serializeForm(formEl)).toEqual({
  slug: 'primal',
  allowed_origins: ['https://primal.net'],
  allowed_methods: ['getPublicKey', 'signEvent'],
  allowed_sign_event_kinds: [1, 4],
  prompt_required_for: ['nip44.decrypt'],
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd website/apps-admin && npm install && npm test
```

Expected: FAIL because the admin app and serializer do not exist.

- [ ] **Step 3: Implement the admin console**

Create a minimal static app that:
- lists current manifests
- edits one app at a time
- submits JSON to `/v1/admin/apps`
- loads audit rows from `/v1/admin/audit-events`

Core fetch shape:

```js
export async function saveApp(payload) {
  const response = await fetch('/v1/admin/apps', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error('Failed to save app');
  return response.json();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd website/apps-admin && npm test
```

Expected: PASS with form serialization/validation covered.

- [ ] **Step 5: Commit**

```bash
git add website/apps-admin
git commit -m "feat(apps): add admin console for vetted sandbox apps"
```

## Chunk 3: Mobile Directory Models, Config, And Entry UI

### Task 5: Add mobile config, models, and directory service

**Files:**
- Modify: `mobile/lib/config/app_config.dart`
- Create: `mobile/lib/models/nostr_app_directory_entry.dart`
- Create: `mobile/lib/services/nostr_app_directory_service.dart`
- Modify: `mobile/lib/providers/app_providers.dart`
- Test: `mobile/test/services/nostr_app_directory_service_test.dart`

- [ ] **Step 1: Write failing directory service tests**

Cover:

```dart
expect(await service.fetchApprovedApps(), hasLength(2));
expect(await service.fetchApprovedApps(useCacheOnly: true), hasLength(2));
```

and revocation behavior where a previously cached app disappears after refresh.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd mobile && flutter test test/services/nostr_app_directory_service_test.dart
```

Expected: FAIL because the config, model, and service do not exist.

- [ ] **Step 3: Implement config and service**

Add:

```dart
static const String appsDirectoryBaseUrl = String.fromEnvironment(
  'APPS_DIRECTORY_URL',
  defaultValue: 'https://apps.divine.video',
);
```

and a service API shaped like:

```dart
Future<List<NostrAppDirectoryEntry>> fetchApprovedApps({
  bool useCacheOnly = false,
});
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd mobile && flutter test test/services/nostr_app_directory_service_test.dart
```

Expected: PASS with remote fetch, cache, and revoke handling covered.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/config/app_config.dart mobile/lib/models/nostr_app_directory_entry.dart mobile/lib/services/nostr_app_directory_service.dart mobile/lib/providers/app_providers.dart mobile/test/services/nostr_app_directory_service_test.dart
git commit -m "feat(apps): add mobile directory models and cache service"
```

### Task 6: Add settings entry and directory screens

**Files:**
- Create: `mobile/lib/screens/apps/apps_directory_screen.dart`
- Create: `mobile/lib/screens/apps/app_detail_screen.dart`
- Modify: `mobile/lib/screens/settings/settings_screen.dart`
- Modify: `mobile/lib/router/app_router.dart`
- Modify: `mobile/lib/router/providers/page_context_provider.dart`
- Modify: `mobile/test/widgets/settings_screen_test.dart`
- Modify: `mobile/test/router/all_routes_test.dart`
- Modify: `mobile/test/router/route_coverage_test.dart`
- Test: `mobile/test/screens/apps/apps_directory_screen_test.dart`

- [ ] **Step 1: Write failing widget and route tests**

Add expectations for:

```dart
find.text('Apps')
find.byType(AppsDirectoryScreen)
```

and route coverage for the new settings entry.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd mobile && flutter test test/widgets/settings_screen_test.dart test/router/all_routes_test.dart test/router/route_coverage_test.dart test/screens/apps/apps_directory_screen_test.dart
```

Expected: FAIL because the screens and routes do not exist.

- [ ] **Step 3: Implement the settings entry and screens**

Add a new settings tile:

```dart
_SettingsTile(
  icon: Icons.apps_rounded,
  title: 'Apps',
  subtitle: 'Launch vetted Nostr apps in Divine',
  onTap: () => context.push(AppsDirectoryScreen.path),
)
```

and a directory screen that loads approved apps from the service.

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
cd mobile && flutter test test/widgets/settings_screen_test.dart test/router/all_routes_test.dart test/router/route_coverage_test.dart test/screens/apps/apps_directory_screen_test.dart
```

Expected: PASS with settings navigation and directory rendering covered.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/apps mobile/lib/screens/settings/settings_screen.dart mobile/lib/router/app_router.dart mobile/lib/router/providers/page_context_provider.dart mobile/test/widgets/settings_screen_test.dart mobile/test/router/all_routes_test.dart mobile/test/router/route_coverage_test.dart mobile/test/screens/apps/apps_directory_screen_test.dart
git commit -m "feat(apps): add settings entry and mobile app directory UI"
```

## Chunk 4: Sandbox WebView And Origin Enforcement

### Task 7: Add WebView dependency and sandbox shell

**Files:**
- Modify: `mobile/pubspec.yaml`
- Create: `mobile/lib/screens/apps/nostr_app_sandbox_screen.dart`
- Test: `mobile/test/screens/apps/nostr_app_sandbox_screen_test.dart`

- [ ] **Step 1: Write the failing sandbox shell test**

Cover:

```dart
expect(find.text('Blocked for safety'), findsOneWidget);
```

for an off-origin navigation callback, and a loading state for initial launch.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd mobile && flutter test test/screens/apps/nostr_app_sandbox_screen_test.dart
```

Expected: FAIL because the sandbox screen and WebView integration do not exist.

- [ ] **Step 3: Add the WebView package and screen**

Add `webview_flutter` to `mobile/pubspec.yaml`, run `flutter pub get`, and implement:

```dart
class NostrAppSandboxScreen extends ConsumerStatefulWidget {
  static const path = '/apps/:appId/sandbox';
}
```

with a `NavigationDelegate` that blocks non-allowlisted origins.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd mobile && flutter test test/screens/apps/nostr_app_sandbox_screen_test.dart
```

Expected: PASS with basic origin-block UX covered.

- [ ] **Step 5: Commit**

```bash
git add mobile/pubspec.yaml mobile/lib/screens/apps/nostr_app_sandbox_screen.dart mobile/test/screens/apps/nostr_app_sandbox_screen_test.dart
git commit -m "feat(apps): add sandbox webview shell"
```

### Task 8: Add bridge policy and remembered grants

**Files:**
- Create: `mobile/lib/services/nostr_app_grant_store.dart`
- Create: `mobile/lib/services/nostr_app_bridge_policy.dart`
- Modify: `mobile/lib/providers/app_providers.dart`
- Test: `mobile/test/services/nostr_app_bridge_policy_test.dart`

- [ ] **Step 1: Write failing policy tests**

Cover:

```dart
expect(
  policy.evaluate(
    app: primalApp,
    origin: Uri.parse('https://primal.net'),
    method: 'signEvent',
    eventKind: 1,
  ).decision,
  BridgeDecision.prompt,
);
```

and failures for blocked origins, blocked methods, and blocked event kinds.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd mobile && flutter test test/services/nostr_app_bridge_policy_test.dart
```

Expected: FAIL because the policy and grant storage do not exist.

- [ ] **Step 3: Implement grant storage and policy**

Add a store API:

```dart
Future<void> saveGrant({
  required String userPubkey,
  required String appId,
  required String origin,
  required String capability,
});
```

and policy evaluation:

```dart
BridgeEvaluation evaluate({
  required NostrAppDirectoryEntry app,
  required Uri origin,
  required String method,
  int? eventKind,
});
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd mobile && flutter test test/services/nostr_app_bridge_policy_test.dart
```

Expected: PASS with deterministic allow/prompt/deny decisions.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/services/nostr_app_grant_store.dart mobile/lib/services/nostr_app_bridge_policy.dart mobile/lib/providers/app_providers.dart mobile/test/services/nostr_app_bridge_policy_test.dart
git commit -m "feat(apps): add sandbox bridge policy and remembered grants"
```

## Chunk 5: Native Bridge Execution, Prompts, And Audit

### Task 9: Add the native bridge service and prompt UI

**Files:**
- Create: `mobile/lib/services/nostr_app_bridge_service.dart`
- Create: `mobile/lib/widgets/apps/nostr_app_permission_prompt_sheet.dart`
- Modify: `mobile/lib/screens/apps/nostr_app_sandbox_screen.dart`
- Test: `mobile/test/services/nostr_app_bridge_service_test.dart`

- [ ] **Step 1: Write failing bridge service tests**

Cover:

```dart
final result = await service.handleRequest(
  app: primalApp,
  origin: Uri.parse('https://primal.net'),
  method: 'getPublicKey',
  args: const {},
);
expect(result.success, isTrue);
```

plus failure cases for unsupported methods and blocked event kinds.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd mobile && flutter test test/services/nostr_app_bridge_service_test.dart
```

Expected: FAIL because bridge execution does not exist.

- [ ] **Step 3: Implement the bridge service and prompt flow**

Implement a dispatcher with narrow method support:

```dart
switch (request.method) {
  case 'getPublicKey':
    return BridgeResult.success(await authService.currentPublicKeyHex());
  case 'signEvent':
    return _handleSignEvent(...);
  case 'nip44.encrypt':
    return _handleNip44Encrypt(...);
  case 'nip44.decrypt':
    return _handleNip44Decrypt(...);
  default:
    return BridgeResult.error('unsupported_method');
}
```

Show `VineBottomSheet` prompt UI when policy requires approval.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd mobile && flutter test test/services/nostr_app_bridge_service_test.dart
```

Expected: PASS with method routing and fail-closed behavior covered.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/services/nostr_app_bridge_service.dart mobile/lib/widgets/apps/nostr_app_permission_prompt_sheet.dart mobile/lib/screens/apps/nostr_app_sandbox_screen.dart mobile/test/services/nostr_app_bridge_service_test.dart
git commit -m "feat(apps): add native sandbox bridge and permission prompts"
```

### Task 10: Add local and remote audit logging with NIP-98 upload

**Files:**
- Create: `mobile/lib/models/nostr_app_audit_event.dart`
- Create: `mobile/lib/services/nostr_app_audit_service.dart`
- Modify: `mobile/lib/services/nostr_app_bridge_service.dart`
- Modify: `mobile/lib/providers/app_providers.dart`
- Test: `mobile/test/services/nostr_app_audit_service_test.dart`
- Modify: `website/apps-directory-worker/src/lib/nip98.ts`
- Modify: `website/apps-directory-worker/src/lib/audit-store.ts`
- Modify: `website/apps-directory-worker/src/index.ts`
- Test: `website/apps-directory-worker/test/routes.test.ts`

- [ ] **Step 1: Write failing audit tests on both mobile and worker**

Cover:
- mobile records sanitized event metadata
- mobile uploads with `Authorization: Nostr ...`
- worker rejects missing/invalid NIP-98
- worker accepts valid audit payloads

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd mobile && flutter test test/services/nostr_app_audit_service_test.dart
cd ../website/apps-directory-worker && npm test
```

Expected: FAIL because audit services and endpoint do not exist.

- [ ] **Step 3: Implement audit models, upload, and worker ingest**

Mobile event shape:

```dart
{
  'appId': appId,
  'origin': origin,
  'method': method,
  'eventKind': eventKind,
  'decision': decision.name,
  'errorCode': errorCode,
}
```

Worker route:

```ts
if (request.method === 'POST' && url.pathname === '/v1/audit-events') {
  const pubkey = await verifyNip98(request);
  const payload = await request.json();
  await auditStore.insert({ ...payload, user_pubkey: pubkey });
  return Response.json({ success: true });
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
cd mobile && flutter test test/services/nostr_app_audit_service_test.dart
cd ../website/apps-directory-worker && npm test
```

Expected: PASS with sanitized local and remote audit behavior covered.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/models/nostr_app_audit_event.dart mobile/lib/services/nostr_app_audit_service.dart mobile/lib/services/nostr_app_bridge_service.dart mobile/lib/providers/app_providers.dart mobile/test/services/nostr_app_audit_service_test.dart website/apps-directory-worker/src/lib/nip98.ts website/apps-directory-worker/src/lib/audit-store.ts website/apps-directory-worker/src/index.ts website/apps-directory-worker/test/routes.test.ts
git commit -m "feat(apps): add sandbox audit logging and upload"
```

## Chunk 6: Revocation, Settings, And Final Verification

### Task 11: Add grant-management settings and revocation handling

**Files:**
- Modify: `mobile/lib/screens/apps/app_detail_screen.dart`
- Modify: `mobile/lib/screens/settings/settings_screen.dart`
- Create or Modify: `mobile/lib/screens/apps/apps_permissions_screen.dart`
- Modify: `mobile/lib/services/nostr_app_directory_service.dart`
- Modify: `mobile/lib/services/nostr_app_grant_store.dart`
- Test: `mobile/test/screens/apps/apps_directory_screen_test.dart`
- Test: `mobile/test/services/nostr_app_directory_service_test.dart`

- [ ] **Step 1: Write failing tests for revoke and grant-management UX**

Cover:
- revoked app disappears or disables after refresh
- user can revoke remembered permissions
- app detail reflects revoked/disabled state

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd mobile && flutter test test/screens/apps/apps_directory_screen_test.dart test/services/nostr_app_directory_service_test.dart
```

Expected: FAIL because grant-management UI and revoke handling are incomplete.

- [ ] **Step 3: Implement revoke and permissions management**

Add a simple management surface listing stored grants and a revoke action:

```dart
await grantStore.revokeGrant(
  userPubkey: currentUserPubkey,
  appId: appId,
  origin: origin,
  capability: capability,
);
```

Update directory refresh so revoked apps lose launch access immediately.

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
cd mobile && flutter test test/screens/apps/apps_directory_screen_test.dart test/services/nostr_app_directory_service_test.dart
```

Expected: PASS with revoke and user-managed grant behavior covered.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/apps mobile/lib/screens/settings/settings_screen.dart mobile/lib/services/nostr_app_directory_service.dart mobile/lib/services/nostr_app_grant_store.dart mobile/test/screens/apps/apps_directory_screen_test.dart mobile/test/services/nostr_app_directory_service_test.dart
git commit -m "feat(apps): add revocation and grant management"
```

### Task 12: Run final focused verification and update docs

**Files:**
- Modify: `docs/superpowers/specs/2026-03-25-vetted-nostr-app-sandbox-design.md`
  if implementation reality diverges
- Modify: `docs/superpowers/plans/2026-03-25-vetted-nostr-app-sandbox.md`
  to mark deviations if needed

- [ ] **Step 1: Run worker test suite**

Run:

```bash
cd website/apps-directory-worker && npm test
```

Expected: PASS.

- [ ] **Step 2: Run admin UI test suite**

Run:

```bash
cd website/apps-admin && npm test
```

Expected: PASS.

- [ ] **Step 3: Run focused mobile tests**

Run:

```bash
cd mobile && flutter test \
  test/services/nostr_app_directory_service_test.dart \
  test/services/nostr_app_bridge_policy_test.dart \
  test/services/nostr_app_bridge_service_test.dart \
  test/services/nostr_app_audit_service_test.dart \
  test/screens/apps/apps_directory_screen_test.dart \
  test/screens/apps/nostr_app_sandbox_screen_test.dart \
  test/widgets/settings_screen_test.dart \
  test/router/all_routes_test.dart \
  test/router/route_coverage_test.dart
```

Expected: PASS.

- [ ] **Step 4: Review and clean the diff**

Run:

```bash
git status --short
git diff --stat
```

Expected: only task-related files remain.

- [ ] **Step 5: Commit**

```bash
git add website/apps-directory-worker website/apps-admin mobile docs/superpowers/specs/2026-03-25-vetted-nostr-app-sandbox-design.md docs/superpowers/plans/2026-03-25-vetted-nostr-app-sandbox.md
git commit -m "feat(apps): add vetted nostr app sandbox and directory"
```
