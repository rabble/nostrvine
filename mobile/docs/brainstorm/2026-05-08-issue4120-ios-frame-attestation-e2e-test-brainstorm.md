# Brainstorm: end-to-end EventChannel coverage for iOS frame attestation

Date: 2026-05-08

Issue: [#4120](https://github.com/divinevideo/divine-mobile/issues/4120)
Follow-up to: PR [#3979](https://github.com/divinevideo/divine-mobile/pull/3979) (closed
[#3764](https://github.com/divinevideo/divine-mobile/issues/3764))

## Problem Statement

PR #3979 shipped iOS per-frame origin attestation: a custom
`WKScriptMessageHandler` reads `WKScriptMessage.frameInfo.isMainFrame` and
streams `{message, isMainFrame}` to Dart through an `EventChannel`. The Dart
reaction is unit-tested via the `@visibleForTesting onAttestedEventHandlerReady`
seam, and the Swift policy + payload shape are pinned by `RunnerTests.swift`.
**No test exercises the live `WKScriptMessage → Swift handler → EventChannel →
Dart` hop.** A channel-name typo, payload-key drift, broadcast-stream
lifecycle bug, or marshaling regression on either side would silently degrade
defence-in-depth to nonce-only enforcement, and every existing test would
still be green.

## Constraints

- **iOS-only feature.** The native plugin lives in
  `mobile/ios/Runner/NostrBridgeAttestationPlugin.swift`. Android keeps its
  current nonce-only posture (parity tracked separately in #4105). The new test
  must skip on `!= TargetPlatform.iOS`.
- **`webview_flutter_wkwebview: ^3.24.1`.** Pigeon definition of
  `WKScriptMessage` does not include `frameInfo` — that's exactly why the
  native plugin was needed. The test cannot reach `frameInfo` from Dart; it
  must let the live `WKWebView` produce the `WKScriptMessage` in flight.
- **Production routing on iOS uses `loadRequest(uri)`** (the
  `_BootstrappedSandboxPage` path is gated on Android). The fixture must be
  loadable as a real URL.
- **Allowed-origin gate**: `_isAllowedOrigin` requires the loaded page's
  origin to exactly match an entry in `NostrAppDirectoryEntry.allowedOrigins`.
  Fixtures need to drive both sides of that.
- **Bootstrap script is `forMainFrameOnly: true`** — by design. The iframe
  has no `__divineBridgeNonce` constant; the only available channel is
  `webkit.messageHandlers.divineSandboxBridge.postMessage(...)` raw. That is
  exactly the attack vector PR #3979 closes.
- **`patrol: ^4.2.0` is the integration-test harness for tests that need
  OS-level automation** (`auth/`, `lifecycle/`, etc.). Tests that don't need
  patrol's native side run as plain `testWidgets` against the
  `IntegrationTestWidgetsFlutterBinding`, executable directly via
  `flutter test integration_test/...` — the new test follows that pattern.
- **Repo rules**: layered architecture, no error strings in BLoC state, no
  hardcoded values without a named constant, l10n for any user-visible
  string. None of these bite hard for a test, but the test fixture should
  pull constants out (channel names, nonce, pubkey) into named consts.

## Prior Art

- **PR #3979** ships the feature under test. Plugin lives at
  `mobile/ios/Runner/NostrBridgeAttestationPlugin.swift`. Test seam exposed
  at `mobile/lib/screens/apps/nostr_app_sandbox_screen.dart:53-54`
  (`onAttestedEventHandlerReady`) and `:39-58` (`bridgeNonceOverride`,
  `currentUserPubkeyOverride`, `javaScriptRunnerOverride`,
  `bridgeServiceOverride`).
- **`mobile/test/screens/apps/nostr_app_sandbox_screen_test.dart:406-572`**:
  the `iOS frame attestation` group exercises the Dart-side handler in
  isolation. It is the contract this E2E test layers above.
- **`mobile/ios/RunnerTests/RunnerTests.swift`**:
  `FrameAttestingScriptMessageHandlerTests` pin the dictionary shape;
  `WebKitContentControllerIntegrationTests` smoke-test the WebKit APIs the
  plugin depends on. Neither exercises Flutter channels.
- **`mobile/integration_test/privacy/image_metadata_stripper_test.dart`**:
  closest existing template for a single-feature, native-plugin integration
  test driven from Dart. No full app launch.
- **`mobile/integration_test/secure_key_storage_test.dart`**: another
  feature-isolated integration test using `patrolTest($)` without app launch.
- **`mobile/integration_test/helpers/`**: reusable helpers for HTTP, db,
  navigation, relay, services. None currently bind a local server inside a
  test process — that pattern is net-new.
- **`webview_flutter` `WKUserContentController.add(_:name:)`** does not take
  `forMainFrameOnly` — handlers are reachable from sub-frames by design.
  The defence is reading `frameInfo.isMainFrame` in the handler, not blocking
  the post.

## Approaches Explored

### Approach A: in-process `dart:io` HTTP server + `<iframe src="/iframe.html">`

**Description.** The integration test binds an `HttpServer` to
`127.0.0.1:0`, serves two endpoints from the same origin:

- `GET /` → main HTML. The bootstrap script (installed by the native
  plugin as `WKUserScript`, document-start, main-frame only) takes care of
  `window.nostr`; the pigeon's own `addJavaScriptChannel` install aliases
  `window.divineSandboxBridge → webkit.messageHandlers.divineSandboxBridge`.
  The main page's body fires
  `divineSandboxBridge.postMessage(JSON.stringify({id:'main',method:'getPublicKey',args:{},nonce:'<known>'}))`
  once the alias resolves. The known nonce is supplied via
  `bridgeNonceOverride`.
- `GET /iframe.html` → iframe HTML. Inline script:
  `webkit.messageHandlers.divineSandboxBridge.postMessage(JSON.stringify({id:'frame',method:'getPublicKey',args:{}}))` —
  no nonce, no bootstrap. Mimics the attack vector from #3764.

The main page contains `<iframe src="/iframe.html"></iframe>` so both frames
are same-origin (loopback), and `webkit.messageHandlers.divineSandboxBridge`
is reachable from the iframe.

The fixture `NostrAppDirectoryEntry` carries
`allowedOrigins: ['http://127.0.0.1:<port>']` and
`launchUrl: 'http://127.0.0.1:<port>/'`. Pump `NostrAppSandboxScreen`
inside a `MaterialApp` with `javaScriptRunnerOverride` collecting outbound
`__divineNostrBridge?.handleResponse(...)` calls into a `List<String>`.

Poll the collector (250 ms ticks, 15 s cap) until two specific response
payloads land — one for `id: 'main'`, one for `id: 'frame'` — then assert:

- The `frame` response contains `"subframe_rejected"`.
- The `main` response does NOT contain `"subframe_rejected"`. With a stub
  bridge service wired, additionally assert `"success":true` and the
  pubkey echoed back.

**Layers affected.** Integration test only. No production-code change.

**Pros.**
- Real `WKWebView` produces the real `WKScriptMessage`; the
  `frameInfo.isMainFrame` value comes from WebKit, not from a test fake.
- `<iframe src=...>` is the closest analogue to the production attack
  vector (compromised same-origin asset, XSS into a sub-frame, etc.).
- Exercises every link in the chain: WKScriptMessageHandler swap,
  `FrameAttestingScriptMessageHandler.userContentController`, dictionary
  marshal, `FlutterEventSink`, `EventChannel.receiveBroadcastStream()`,
  `_handleAttestedEvent`'s map-key reads, `_emitBridgeResponse`.
- Reuses the existing `javaScriptRunnerOverride` seam — same assertion
  shape as the unit tests.
- Single Dart file (plus optional helper). No iOS test target changes.

**Cons.**
- Net-new pattern: no existing `mobile/integration_test/` test binds a
  local HTTP server. Slight risk of port-binding flake; mitigated by
  `bind('127.0.0.1', 0)` and reading the actual port back from
  `server.port`.
- Test must run on a device/simulator where loopback HTTP is reachable
  (it is, on iOS simulators by default). App Transport Security may need
  an exception for `127.0.0.1` HTTP for device runs.

**Risks / Unknowns.**
- iOS may rewrite the loopback origin in some way (`http://localhost`
  vs `http://127.0.0.1`); the fixture must use whichever one
  `WKWebView` reports back. Local testing confirms which form to embed
  in `allowedOrigins`.
- Timing: the main page's `_postMain()` may fire before the alias is
  available; polling for the alias in the fixture script handles this.
- The captured-scripts collector relies on `_emitBridgeResponse` running
  successfully — the `_runJavaScript` override has to succeed, otherwise
  the production code throws and the test stalls.

**Complexity:** Medium.

### Approach B: in-process HTTP server + `<iframe srcdoc="...">`

**Description.** Same as Approach A, but the iframe is inline:
`<iframe srcdoc="<script>webkit.messageHandlers.divineSandboxBridge.postMessage(...)</script>"></iframe>`.
Only one endpoint to serve.

**Pros.**
- Slightly simpler: one HTML body, one route handler.
- No risk of iframe failing to load (no second network hop).

**Cons.**
- WebKit's treatment of `srcdoc` iframes vs same-origin `src=` iframes
  is subtly different. `srcdoc` iframes inherit the embedder's origin —
  `frameInfo.isMainFrame` is correctly `false`, so the test is sound —
  but `webkit.messageHandlers` exposure to `srcdoc` iframes has shifted
  in past iOS versions. We'd be coupling test reliability to that quirk.
- Less faithful to the production attack vector. The realistic threat is
  a compromised same-origin URL, not a `srcdoc` injection.

**Risks / Unknowns.**
- `srcdoc` script execution and `webkit.messageHandlers` scope on iOS 18+.
  Could regress unrelated to the fix-under-test.

**Complexity:** Low.

### Approach C: bundled-asset HTML loaded via `loadFlutterAsset` / `file://`

**Description.** Add a fixture HTML pair under
`mobile/integration_test/fixtures/` (or as test_assets) and load via
`controller.loadFlutterAsset(...)`. No HTTP server.

**Pros.**
- No network code in the test.
- Asset bundle ships with the test binary; no port binding.

**Cons.**
- `file://` and `flutter-asset://` origins are not real HTTP(S) origins.
  `_isAllowedOrigin` matches by `Uri.origin`, which returns an empty
  string for non-HTTP(S) URIs. The production guard would refuse to load
  the page in the first place.
- To make this work, the test would either bypass `allowedOrigins`
  (production-code change ruled out by scope) or override
  `sandboxBuilder` to skip the WebView entirely — which reduces to the
  existing unit-test seam.
- Asset declarations would land in the production `pubspec.yaml`,
  shipping fixture HTML to end-users.

**Risks / Unknowns.**
- Doesn't satisfy the issue's intent. Cut.

**Complexity:** Misleadingly low — turns out infeasible without a
production-code carve-out.

### Approach D: pure native XCUITest layer

**Description.** Add an XCUITest target that loads a real `WKWebView`,
installs `FrameAttestingScriptMessageHandler` directly, and asserts the
`FlutterEventSink` is invoked with the right payload via a stub sink.

**Pros.**
- Native fidelity: no Dart, no `EventChannel` cost.

**Cons.**
- Issue body is explicit: *"add an integration test using
  `package:integration_test`"*. XCUITest doesn't satisfy that ask.
- Doesn't cover the Dart-side reaction (`_handleAttestedEvent`,
  `_emitBridgeResponse`).

**Complexity:** Low for the native side; ignores half the surface.

## Decision

**Approach A** — in-process HTTP server with two same-origin endpoints
(`/` main + `/iframe.html` subframe). Landed in PR #4134.

Why:

1. **Faithfulness to the threat model.** `<iframe src="/iframe.html">`
   maps directly onto the threat in #3764: a same-origin asset is
   compromised and posts to `webkit.messageHandlers.divineSandboxBridge`
   from a sub-frame. `srcdoc` (Approach B) is a less realistic vector
   and couples to WebKit `srcdoc` quirks.
2. **Coverage of the live hop.** The live `WKWebView` produces the
   `WKScriptMessage` with a real `frameInfo`, the native handler
   receives it, the dictionary is marshaled across the Flutter
   `EventChannel`, and the Dart reaction runs. Every link the unit test
   skips is exercised.
3. **No production-code changes.** All other approaches either touch
   production guards (Approach C) or fail to satisfy the issue scope
   (Approach D).
4. **Reuse over invention.** The assertion mechanic (capture
   `_runJavaScript` calls into a list and grep response payloads for
   `subframe_rejected`) is identical to the existing widget test —
   reviewers already know this shape from
   `nostr_app_sandbox_screen_test.dart`.

## Resolved Questions

- **Loopback origin form.** WKWebView preserves `http://127.0.0.1:<port>`
  verbatim through `loadRequest` on iPhone 17 Pro / iOS 26.4. The fixture
  uses the literal IP form in both `launchUrl` and `allowedOrigins`; no
  rewrite to `localhost` was observed.
- **Stub `BridgeService`.** Wired for the main-frame test
  (`bridgeServiceOverride` + private `_FakeAuthProvider` /
  `_FakeNostrSigner`). The iframe test omits it because rejection
  happens before `_handleBridgeMessage` runs.
- **Polling timeout budget.** 15 s is comfortable headroom. On
  iPhone 17 Pro / iOS 26.4 / Flutter 3.41.4 the `iframe`
  response landed in ~1 s and the `main` response in ~1 s across 3
  consecutive runs. Even with cold caches the slowest tail observed was
  under 2 s.
- **App Transport Security.** No Info.plist change is needed for this
  PR. `mobile/ios/Runner/Info.plist` already declares
  `NSAllowsLocalNetworking=true` under `NSAppTransportSecurity`, which
  permits cleartext HTTP/WS to `localhost`, `127.0.0.1`, `::1`,
  single-label hostnames, and the `.local` TLD on both simulator and
  device (remote cleartext stays rejected). The fixture's
  `http://127.0.0.1:<port>` loopback URL is covered by that exemption
  verbatim, so the test runs identically on simulator and physical-device
  targets without any test-specific carve-out. The exemption mirrors the
  loopback domain-config in
  `android/app/src/main/res/xml/network_security_config.xml`.
- **Test harness choice.** `testWidgets` against
  `IntegrationTestWidgetsFlutterBinding`, not `patrolTest`. This test
  doesn't need patrol's native automation, and `flutter test
  integration_test/apps/...` is the simplest invocation. Patrol's
  `PatrolBinding` and the auto-installed `IntegrationTestWidgetsFlutterBinding`
  conflict when invoked through `flutter test` (assertion failure on
  binding init), so adopting plain `testWidgets` was the cleaner path
  rather than introducing the patrol CLI as a new dependency.
