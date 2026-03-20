# GitHub Actions Pages Preview Invite Bypass Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make GitHub Actions Cloudflare Pages preview builds skip invite-code gating without changing local or production web behavior.

**Architecture:** Add an explicit preview-only build flag in `AppConfig`, default `InviteApiService` to that flag, and override the fetched onboarding mode to `open` when the flag is enabled. Rely on the existing invite-gate screens and route guard, which already allow account creation when onboarding mode is open.

**Tech Stack:** Flutter, Dart, flutter_test, mocktail, GitHub Actions

**Spec:** `docs/superpowers/specs/2026-03-20-pages-preview-invite-bypass-design.md`

---

## Chunk 1: Preview Flag And Invite Config Override

### Task 1: Add failing service tests for the preview bypass

**Files:**
- Modify: `mobile/test/services/invite_api_service_test.dart`
- Modify: `mobile/lib/services/invite_api_service.dart`
- Modify: `mobile/lib/config/app_config.dart`

- [ ] **Step 1: Write the failing tests**

Add these tests to `mobile/test/services/invite_api_service_test.dart` inside `group('InviteApiService', () {`:

```dart
test('forces onboarding mode open for GH preview builds', () async {
  final response = _MockResponse();
  when(() => response.statusCode).thenReturn(200);
  when(() => response.body).thenReturn(
    jsonEncode({
      'onboarding_mode': 'invite_code_required',
      'support_email': 'support@divine.video',
    }),
  );
  when(
    () => mockClient.get(any(), headers: any(named: 'headers')),
  ).thenAnswer((_) async => response);

  final previewInviteApiService = InviteApiService(
    client: mockClient,
    forceOpenOnboarding: true,
  );

  final config = await previewInviteApiService.getClientConfig();

  expect(config.mode, OnboardingMode.open);
  expect(config.supportEmail, 'support@divine.video');
});

test('preserves server onboarding mode when preview bypass is disabled', () async {
  final response = _MockResponse();
  when(() => response.statusCode).thenReturn(200);
  when(() => response.body).thenReturn(
    jsonEncode({
      'onboarding_mode': 'invite_code_required',
      'support_email': 'support@divine.video',
    }),
  );
  when(
    () => mockClient.get(any(), headers: any(named: 'headers')),
  ).thenAnswer((_) async => response);

  final standardInviteApiService = InviteApiService(
    client: mockClient,
    forceOpenOnboarding: false,
  );

  final config = await standardInviteApiService.getClientConfig();

  expect(config.mode, OnboardingMode.inviteCodeRequired);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd mobile && flutter test test/services/invite_api_service_test.dart --plain-name "forces onboarding mode open for GH preview builds"`

Expected: FAIL because `InviteApiService` does not accept `forceOpenOnboarding` yet and there is no preview override.

- [ ] **Step 3: Write the minimal implementation**

In `mobile/lib/config/app_config.dart`, add a dedicated preview flag:

```dart
static const bool isGhActionsPrPreviewBuild = bool.fromEnvironment(
  'GH_ACTIONS_PR_PREVIEW',
  defaultValue: false,
);
```

Also add it to `getConfigSummary()`.

In `mobile/lib/services/invite_api_service.dart`, update the constructor and `getClientConfig()`:

```dart
InviteApiService({
  http.Client? client,
  Nip98AuthService? authService,
  bool? forceOpenOnboarding,
}) : _client = client ?? http.Client(),
     _authService = authService,
     _forceOpenOnboarding =
         forceOpenOnboarding ?? AppConfig.isGhActionsPrPreviewBuild;

final bool _forceOpenOnboarding;
```

Then override the parsed config only when the preview flag is enabled:

```dart
final config = InviteClientConfig.fromJson(json);
if (!_forceOpenOnboarding) {
  return config;
}

return InviteClientConfig(
  mode: OnboardingMode.open,
  supportEmail: config.supportEmail,
);
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd mobile && flutter test test/services/invite_api_service_test.dart`

Expected: PASS for the new preview override tests and the existing invite service tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/config/app_config.dart mobile/lib/services/invite_api_service.dart mobile/test/services/invite_api_service_test.dart
git commit -m "feat(web): add GH preview invite bypass flag"
```

## Chunk 2: Route-Level Regression Coverage

### Task 2: Add a failing invite-gate screen test that uses the real preview override

**Files:**
- Modify: `mobile/test/screens/auth/invite_gate_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Add lightweight HTTP client test doubles near the top of `mobile/test/screens/auth/invite_gate_screen_test.dart`:

```dart
class _MockHttpClient extends Mock implements http.Client {}
class _MockResponse extends Mock implements http.Response {}
```

Register fallback values in `setUpAll()`:

```dart
setUpAll(() {
  registerFallbackValue(Uri.parse('https://example.com'));
  registerFallbackValue(<String, String>{});
});
```

Then add this test:

```dart
testWidgets('preview bypass continues past invite gate when server requires invites', (
  tester,
) async {
  final mockClient = _MockHttpClient();
  final response = _MockResponse();
  when(() => response.statusCode).thenReturn(200);
  when(() => response.body).thenReturn(
    jsonEncode({
      'onboarding_mode': 'invite_code_required',
      'support_email': 'support@divine.video',
    }),
  );
  when(
    () => mockClient.get(any(), headers: any(named: 'headers')),
  ).thenAnswer((_) async => response);

  final previewInviteApiService = InviteApiService(
    client: mockClient,
    forceOpenOnboarding: true,
  );

  await tester.pumpWidget(createTestWidget(inviteApiService: previewInviteApiService));
  await tester.pumpAndSettle();

  expect(find.text('Create Account'), findsOneWidget);
});
```

Update `createTestWidget` to accept an optional `InviteApiService inviteApiService` parameter and use that instead of always creating the mock service.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd mobile && flutter test test/screens/auth/invite_gate_screen_test.dart --plain-name "preview bypass continues past invite gate when server requires invites"`

Expected: FAIL because `InviteApiService(forceOpenOnboarding: true)` does not exist yet or because the screen still stays on invite entry.

- [ ] **Step 3: Adjust the test harness minimally**

If the test still uses the mock-only helper, update `createTestWidget` so existing tests keep passing:

```dart
Widget createTestWidget({InviteApiService? inviteApiService}) {
  final service = inviteApiService ?? mockInviteApiService;
  return RepositoryProvider<InviteApiService>.value(
    value: service,
    child: BlocProvider(
      create: (_) => InviteGateBloc(inviteApiService: service),
      ...
    ),
  );
}
```

Do not add new production code in this step beyond what Task 1 already introduced.

- [ ] **Step 4: Run the screen tests to verify they pass**

Run: `cd mobile && flutter test test/screens/auth/invite_gate_screen_test.dart`

Expected: PASS, including the new preview-bypass regression test and the existing invite gate tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/test/screens/auth/invite_gate_screen_test.dart
git commit -m "test(web): cover preview invite bypass at invite gate"
```

### Task 3: Add a failing protected create-account route test for preview bypass

**Files:**
- Modify: `mobile/test/screens/auth/invite_protected_create_account_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Add HTTP client test doubles if the file does not already have them, then add:

```dart
testWidgets('preview bypass allows direct create-account access without invite grant', (
  tester,
) async {
  final mockClient = _MockHttpClient();
  final response = _MockResponse();
  when(() => response.statusCode).thenReturn(200);
  when(() => response.body).thenReturn(
    jsonEncode({
      'onboarding_mode': 'invite_code_required',
      'support_email': 'support@divine.video',
    }),
  );
  when(
    () => mockClient.get(any(), headers: any(named: 'headers')),
  ).thenAnswer((_) async => response);

  final previewInviteApiService = InviteApiService(
    client: mockClient,
    forceOpenOnboarding: true,
  );

  await tester.pumpWidget(createTestWidget(inviteApiService: previewInviteApiService));
  await tester.pumpAndSettle();

  expect(find.widgetWithText(DivineAuthTextField, 'Email'), findsOneWidget);
});
```

Update the test helper so it accepts an optional `InviteApiService inviteApiService` parameter and uses that real service when supplied.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd mobile && flutter test test/screens/auth/invite_protected_create_account_screen_test.dart --plain-name "preview bypass allows direct create-account access without invite grant"`

Expected: FAIL before Task 1 lands, because the preview override does not exist.

- [ ] **Step 3: Reuse the Task 1 implementation**

No new production code should be required here if Task 1 is correct. Keep this task focused on test harness updates and regression coverage.

- [ ] **Step 4: Run the protected route tests to verify they pass**

Run: `cd mobile && flutter test test/screens/auth/invite_protected_create_account_screen_test.dart`

Expected: PASS for the new preview-bypass test and the existing invite-protection tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/test/screens/auth/invite_protected_create_account_screen_test.dart
git commit -m "test(web): cover preview bypass for protected signup route"
```

## Chunk 3: GitHub Actions Wiring

### Task 4: Pass the preview-only dart-define from the PR preview workflow

**Files:**
- Modify: `.github/workflows/mobile_pr_preview_build.yml`

- [ ] **Step 1: Update the workflow build command**

In `.github/workflows/mobile_pr_preview_build.yml`, add the new build flag to the existing Flutter web preview build step:

```yaml
          flutter build web \
            --release \
            --tree-shake-icons \
            --optimization-level=4 \
            --pwa-strategy=none \
            --dart-define=BACKEND_URL=https://api.openvine.co \
            --dart-define=ENVIRONMENT=production \
            --dart-define=GH_ACTIONS_PR_PREVIEW=true \
            --no-source-maps
```

- [ ] **Step 2: Verify the workflow references the new flag**

Run: `rg -n "GH_ACTIONS_PR_PREVIEW" .github/workflows/mobile_pr_preview_build.yml mobile/lib/config/app_config.dart mobile/lib/services/invite_api_service.dart`

Expected: exactly one workflow match and the new application code matches.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/mobile_pr_preview_build.yml
git commit -m "ci(web): mark PR preview builds as invite-free"
```

## Chunk 4: Final Verification

### Task 5: Run the focused verification suite and review the diff

**Files:**
- Verify: `mobile/lib/config/app_config.dart`
- Verify: `mobile/lib/services/invite_api_service.dart`
- Verify: `mobile/test/services/invite_api_service_test.dart`
- Verify: `mobile/test/screens/auth/invite_gate_screen_test.dart`
- Verify: `mobile/test/screens/auth/invite_protected_create_account_screen_test.dart`
- Verify: `.github/workflows/mobile_pr_preview_build.yml`

- [ ] **Step 1: Run the focused tests**

Run:

```bash
cd mobile && flutter test \
  test/services/invite_api_service_test.dart \
  test/screens/auth/invite_gate_screen_test.dart \
  test/screens/auth/invite_protected_create_account_screen_test.dart
```

Expected: PASS

- [ ] **Step 2: Review the final diff**

Run:

```bash
git diff -- \
  mobile/lib/config/app_config.dart \
  mobile/lib/services/invite_api_service.dart \
  mobile/test/services/invite_api_service_test.dart \
  mobile/test/screens/auth/invite_gate_screen_test.dart \
  mobile/test/screens/auth/invite_protected_create_account_screen_test.dart \
  .github/workflows/mobile_pr_preview_build.yml
```

Expected: the diff only contains the preview flag, the invite config override, the new regression tests, and the workflow `dart-define`.

- [ ] **Step 3: Commit any final cleanup**

If Step 2 required small cleanup edits, commit them:

```bash
git add mobile/lib/config/app_config.dart mobile/lib/services/invite_api_service.dart mobile/test/services/invite_api_service_test.dart mobile/test/screens/auth/invite_gate_screen_test.dart mobile/test/screens/auth/invite_protected_create_account_screen_test.dart .github/workflows/mobile_pr_preview_build.yml
git commit -m "chore(web): finalize preview invite bypass verification"
```

If no cleanup edits were needed, skip this commit.
