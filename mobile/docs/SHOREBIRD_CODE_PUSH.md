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

Patch commands take no `--flutter-version`. A patch is compiled against
whatever version its release used, which Shorebird resolves from the release.

## Cutting a release

Run `ios-build` or `android-build` in Codemagic as usual. They now produce
Shorebird releases as a side effect of building the store artifact — no extra
step, no change to how you ship.

Publishing behaviour is unchanged: iOS stops at TestFlight
(`submit_to_app_store: false`, internal groups), Android uploads to Play as a
draft. Promotion to production stays manual in both stores.

**Record the version and build number of every release you promote** — e.g.
`1.0.9+247`. That exact string is what a future patch targets.

## Shipping a patch

1. Land the Dart fix on `main` through the normal PR process. A patch is built
   from the current checkout, so the fix must be merged first.
2. Identify the target release: `shorebird patch` needs the version of the
   build that is actually live. `shorebird releases list`, or the Shorebird
   console, shows what exists.
3. Run `ios-patch` or `android-patch` in Codemagic with:
   - `CONFIRM_PATCH` = `YES` (defaults to `NO`; the build aborts otherwise)
   - `RELEASE_VERSION` = the exact release string, e.g. `1.0.9+247`
   - `DEFAULT_ENV` = **the same value the release was built with**
4. Both platforms need their own patch run. There is no combined workflow.

`DEFAULT_ENV` is the easiest thing to get wrong. A mismatch does not fail the
build — it silently repoints patched installs at a different environment.

### A patch targets a release version, not a channel

TestFlight build `1.0.9+247` and App Store build `1.0.9+247` are the same
Shorebird release. There is no way to patch "just the TestFlight build". If
that version was promoted to the App Store, patching it reaches production
users too, within about one app launch, with no store review and no rollback.

Treat every patch as a production deploy.

## Credentials

CI authenticates with `SHOREBIRD_TOKEN`, held in the `shorebird_credentials`
environment variable group in Codemagic and marked Secret. It is an API key
from the Shorebird console (**Account → API Keys**); `shorebird login:ci` no
longer exists.

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
