# Shorebird Code Push

Shorebird ships Dart-only fixes to already-released builds over the air. A
patch reaches users on their next app launch without a store submission.

Read this before changing anything in `codemagic.yaml` that touches a store
artifact, and before shipping a patch.

## The one rule that matters

**A build is patchable only if it was produced by `shorebird release`.** That
command links the Shorebird updater into the engine; a plain `flutter build`
does not. If a store-bound artifact is ever built with `flutter build`, that
version is permanently unpatchable — there is no way to fix it after the fact
short of shipping a new store release.

This is why the Play AAB and App Store IPA steps in `codemagic.yaml` call
`shorebird release`. Do not "simplify" them back to `flutter build`.

## What can and cannot be patched

| Change | Patchable |
|---|---|
| Dart code — logic, UI, strings | Yes |
| Native code (Kotlin/Swift, plugins with native parts) | No |
| Assets bundled at build time | No |
| Adding or upgrading a dependency with native code | No |
| Flutter or engine version | No |

Shorebird detects native and asset diffs and **refuses** to build the patch.
That refusal is a correctness guard: a patch that disagrees with the binary it
lands on produces crashes that are extremely hard to diagnose in the field.

`--allow-native-diffs` and `--allow-asset-diffs` override the guard. Do not add
them. If a fix needs native changes, it needs a store release.

## How Divine is set up

The app is `mobile/shorebird.yaml` → `app_id`, owned by the **Divine**
organization in Shorebird (not an individual's account).

### Privacy disclosure

Shorebird checks for patches when the app launches. The request includes a
random identifier unique to that app installation, the app, release, and patch
versions, update channel, platform, and device architecture. Shorebird also
records patch download, installation, and failure status. This information is
used to deliver updates, diagnose update failures, and produce aggregated
update and active-install analytics. The installation identifier is not an
advertising identifier and is not used for advertising or cross-app tracking.

Keep the public privacy policy and store disclosures aligned with this
behavior. In App Store Connect, disclose Device ID, Product Interaction, and
Other Diagnostic Data for App Functionality and Analytics, without tracking.
Mark them as not linked only while neither Divine nor Shorebird joins the
installation identifier to Divine account data. In Google Play, disclose Device
or other IDs, App interactions, and Diagnostics as required collection for App
functionality and Analytics. Mark the Google Play data as not shared only while
Shorebird is contractually acting as Divine's service provider or processor.

| Artifact | Built by | Patchable |
|---|---|---|
| Play AAB | `shorebird release android` | Yes |
| App Store IPA | `shorebird release ios` | Yes |
| Zapstore / GitHub per-ABI APKs | `flutter build apk --split-per-abi` | **No** — deliberate |
| macOS DMG | `flutter build macos` | No — not wired |

The Zapstore APKs are an intentional exception: Shorebird has no
`--split-per-abi`, and its universal APK would inflate the download for every
sideload user. Those installs cannot receive patches. Play and App Store
installs can.

`auto_update` is left at its default (on), so patches apply in the background
on launch. `shorebird_code_push` is not a dependency — there is no in-app UI
for controlling or reporting patch state.

### Flutter version

Shorebird ships its own Flutter, so `FLUTTER_VERSION` in `codemagic.yaml`
duplicates the workflow's `flutter:` setting and is passed to
`shorebird release --flutter-version`. **Keep the two in sync**, and when
bumping Flutter, confirm the target is in `shorebird flutter versions list`
first — Shorebird supports a subset.

The current 3.44.9 pin is deliberate. Shorebird's 3.44.0 engine crashed at
launch in the Dart async FFI path used by `cupertino_http`, so the repo and all
CI workflows moved together to the refreshed 3.44.9 Shorebird engine. Do not
move the pin back independently in one workflow.

Patch commands take no `--flutter-version`. A patch is compiled against
whatever version its release used, which Shorebird resolves from the release.

## Cutting a release

Run `ios-build` or `android-build` in Codemagic as usual. They now produce
Shorebird releases as a side effect of building the store artifact — no extra
step, no change to how you ship.

Publishing behaviour is unchanged: iOS stops at TestFlight
(`submit_to_app_store: false`, internal groups), Android uploads to Play as a
draft. Promotion to production stays manual in both stores.

Release commands pass `--public-key-path`, so every new store binary only
accepts signed Shorebird patches. A release built without the public key cannot
be retrofitted later; cut a new store release instead.

**Record the version and build number of every release you promote** — e.g.
`1.0.9+247` — and the git commit that produced it. A future patch needs both.

## Shipping a patch

1. Land the Dart fix on `main` through the normal PR process. A patch is built
   from the current checkout, so the fix must be merged first.
1. Identify the target release: `shorebird patch` needs the version of the
   build that is actually live. `shorebird releases list`, or the Shorebird
   console, shows what exists.
1. Identify the `RELEASE_COMMIT` that produced that store release. The patch
   workflow refuses a release commit that is not an ancestor of the current
   checkout, then prints every commit and Dart file included after that commit.
   Read that list before treating the patch as safe: pure Dart merged since the
   release is exactly what Shorebird can ship.
   If the diff includes native, asset, dependency, or Shorebird config changes,
   the workflow refuses to patch and tells you to cut a normal store release.
1. Run `ios-patch` or `android-patch` in Codemagic with:
   - `CONFIRM_PATCH` = `YES` (defaults to `NO`; the build aborts otherwise)
   - `RELEASE_VERSION` = the exact release string, e.g. `1.0.9+247`
   - `RELEASE_COMMIT` = the git commit that produced the target release
   - `DEFAULT_ENV` = **the same value the release was built with**
1. The workflow publishes to Shorebird's `staging` track, not directly to
   `stable`.
1. Validate the staged patch with `shorebird preview --track staging
   --release-version <version>` or the Shorebird console.
1. Promote the exact patch after validation:

   ```
   shorebird patches promote --release-version <version> --patch-number <n>
   ```

   `shorebird patches set-track --release <version> --patch <n> --track stable`
   is equivalent when you need the lower-level command form.
1. Both platforms need their own patch run. There is no combined workflow.

`DEFAULT_ENV` is the easiest thing to get wrong. A mismatch does not fail the
build — it silently repoints patched installs at a different environment.

### A patch targets a release version, not a channel

TestFlight build `1.0.9+247` and App Store build `1.0.9+247` are the same
Shorebird release. There is no way to patch "just the TestFlight build". If
that version was promoted to the App Store, patching it reaches production
users too once the patch is promoted to `stable`, within about one app launch,
with no store review.

Treat every patch as a production deploy.

### Rollback is recovery, not validation

Shorebird supports patch rollback and on-device rollback from failed patches.
That reduces the worst-case blast radius, but it does not make patching casual:
users can still receive the bad patch before rollback, and rollback does not
replace review, staging validation, signing, or source-diff checks.

## Credentials

CI authenticates with `SHOREBIRD_TOKEN`, held in the `shorebird_credentials`
environment variable group in Codemagic and marked Secret. It is an API key
from the Shorebird console (**Account → API Keys**); `shorebird login:ci` no
longer exists.

The same group holds patch-signing key material:

- `SHOREBIRD_PATCH_PUBLIC_KEY` — public PEM passed to `shorebird release`
- `SHOREBIRD_PATCH_PRIVATE_KEY` — secure private PEM passed to `shorebird patch`

Store both keys as single-line values with literal `\n` sequences between PEM
lines. CI decodes and validates that envelope before invoking Shorebird. Release
jobs only materialize the public key; patch jobs only materialize the private
key.

The token is currently generated from an individual's account. Moving it to a
Divine service identity is tracked in #7200.

## Local setup

Installing the CLI:

```
curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash
```

Then `shorebird login`. You need access to the Divine organization; membership
is managed in the Shorebird console.

`shorebird doctor` from `mobile/` reports one known issue —
`ios/Podfile.lock` is not tracked in source control (`mobile/.gitignore`).
It is worth revisiting, since patches cannot change native code and a release
and its patches should resolve identical pods.

You cannot run `shorebird release android` or `shorebird patch android` on a
machine without a JDK and a complete Android SDK. Android release and patch
builds run on Codemagic, which provisions both. That is also the correct place
for them: a patch should be compiled in the same environment as the release it
targets.

### Known gotchas

**A release build is not idempotent after `shorebird release` succeeds.** If a
later upload or symbol step fails, the store build-number lookup can derive the
same version again, but Shorebird will refuse to create it twice. The preflight
stops that retry before the long build. Delete the failed Shorebird release or
bump the store build number before rerunning; do not bypass the preflight.

**`shorebird init` fails with "Unable to initialize gradlew".** `gradlew` is
gitignored, so a fresh worktree has no wrapper, and `init` calls it directly
rather than through `flutter build`. See #7201. Workaround:

```
echo "flutter.sdk=$HOME/flutter" > mobile/android/local.properties
cd mobile && flutter build apk --config-only   # injects the wrapper
```

`init` also needs a JDK for that call, which a machine set up only for iOS
work will not have.

**`shorebird init` invents a `divineuitests` flavor.** Its iOS detection treats
every shared Xcode scheme that is not `Runner` as a product flavor, and picks up
the `DivineUITests` test target. The app has no product flavors — if a re-init
ever writes a `flavors:` block into `shorebird.yaml`, delete it.

## Reference

- [Shorebird docs](https://docs.shorebird.dev)
- [Codemagic integration](https://docs.shorebird.dev/code-push/ci/codemagic/)
- `codemagic.yaml` — release and patch workflows, setup steps in the header
