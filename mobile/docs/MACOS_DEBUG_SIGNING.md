# macOS Debug Code Signing

Debug builds for the macOS desktop target are code signed. This note
explains why, what it means for a local developer, and how to recover
if a fresh checkout fails to sign.

## What changed

Previously `macos/Flutter/Flutter-Debug.xcconfig` disabled signing
entirely for debug builds:

```
CODE_SIGN_IDENTITY = -
CODE_SIGN_ENTITLEMENTS =
CODE_SIGNING_REQUIRED = NO
CODE_SIGNING_ALLOWED = NO
```

With signing off, the Runner entitlements were never applied, so macOS
never showed the native camera or microphone permission prompts in
debug. The recorder flow could not request access and appeared broken
on debug builds.

Debug builds now **require** signing and apply the debug entitlements:

```
CODE_SIGN_IDENTITY = -
CODE_SIGNING_REQUIRED = YES
CODE_SIGNING_ALLOWED = YES
```

The signing identity is chosen by the Runner target's Debug build
config, which uses `CODE_SIGN_STYLE = Automatic` with
`DEVELOPMENT_TEAM = GZCZBKH7MY`, so a debug build is **team-signed** by
default. The `CODE_SIGN_IDENTITY = -` in the xcconfig sits at a lower
precedence than the target setting and does **not** override it — it is
only a fallback, not an ad-hoc switch. The debug entitlements
(`Runner/DebugProfile.entitlements`) are applied through the Runner
target's own `CODE_SIGN_ENTITLEMENTS`.

Two related changes make that signed debug build run:

1. **Hardened Runtime is enabled** (`ENABLE_HARDENED_RUNTIME = YES`) on
   the Runner target. The camera/microphone TCC prompts and several
   plugins behave consistently across debug, profile, and release once
   the runtime is hardened.

2. **Embedded frameworks are signed with the Runner's identity** in the
   `Codesign media_kit frameworks` build phase (`macos/Podfile`). The
   old phase ad-hoc signed each framework with `--sign -` and no
   runtime hardening. Once Hardened Runtime is on, that is no longer
   sufficient — the loader rejects ad-hoc embedded frameworks whose
   Team ID differs from the host app. The phase now resolves the
   Runner's identity and signs each framework with the runtime option:

   ```bash
   sign_identity="${EXPANDED_CODE_SIGN_IDENTITY:-${CODE_SIGN_IDENTITY:--}}"
   codesign --force --deep --options runtime --sign "$sign_identity" "$framework"
   ```

   `sign_identity` resolves to whatever the Runner is signed with, so the
   app and its embedded frameworks always share one identity and the Team
   IDs match — the team identity for a normal debug build, or ad-hoc `-`
   only if the target identity is unset. The phase now fails the build
   (instead of swallowing the error) if a framework cannot be signed,
   since an unsigned framework would crash the app at launch under
   Hardened Runtime.

## Local setup expectations

Debug builds are signed with the Runner target's automatic-signing
identity for team `GZCZBKH7MY`. If you belong to that team, nothing new
is required:

```bash
cd mobile
flutter run -d macos        # or ./run_dev.sh macos debug
flutter build macos --debug
```

If you are **not** in team `GZCZBKH7MY`, automatic signing fails with a
provisioning or team error. Set your own team locally **without
committing it**: open `macos/Runner.xcworkspace` in Xcode, select the
Runner target, and pick your team under *Signing & Capabilities* for the
Debug configuration. Any Apple ID provides a free personal team that can
sign local debug builds. Keep that change local — never commit a
different `DEVELOPMENT_TEAM`.

## If a stale Swift Package Manager cache blocks the build

Flutter resolves macOS plugins through Swift Package Manager. A stale
SPM cache can fail the build with `Couldn't get revision '<hash>'`
before signing even starts. This is unrelated to code signing — clear
the regenerable caches and rebuild:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/org.swift.swiftpm
cd mobile && flutter clean && flutter pub get
flutter build macos --debug
```

## Verifying the signature

After a debug build, confirm the app and its embedded frameworks carry
the runtime flag:

```bash
APP=mobile/build/macos/Build/Products/Debug/Runner.app
codesign -dvvv "$APP"                       # CodeDirectory flags include "runtime"
codesign --verify --deep --strict "$APP"    # exits 0 when the whole bundle is valid
```
