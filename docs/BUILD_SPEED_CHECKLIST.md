# Build Speed Checklist

Status: Current

Use this checklist when builds slow down before reaching for `flutter clean`.

Run these commands from `mobile/`.

## Start With Fast Defaults

`./build_ios.sh debug` and `./build_macos.sh debug` are the fast defaults.

1) Open a simulator/device run with `./run_dev.sh`.

2) If the app compiles and runs, do not clean pods or run `flutter clean`.

3) If codegen changed, run one explicit rebuild command, then return to `run_dev`.

## When You See Build Errors

### `pod install` or dependency lock issues

1) Run the platform debug script with pod reset once:

```bash
# iOS
./build_ios.sh debug --pod-reset
# macOS
./build_macos.sh debug --pod-reset
```

2) Re-run app:

```bash
# iOS
./run_dev.sh ios debug
# macOS
./run_dev.sh macos debug
```

3) If still broken:

```bash
./clear_cache.sh --full
```

### `generated code` or `build_runner` related errors

1) Regenerate before running:

```bash
# iOS
./build_ios.sh debug --codegen
# macOS
./build_macos.sh debug --codegen
```

2) Retry your run target:

```bash
# iOS
./run_dev.sh ios debug
# macOS
./run_dev.sh macos debug
```

### Reproducible bad local state or flaky startup

1) Fast reset first:

```bash
./clear_cache.sh
```

2) If startup is still corrupted, do full reset:

```bash
./clear_cache.sh --full
```

## Release Builds

1) Use full platform sync path:

```bash
./build_ios.sh release
```

2) For macOS store artifacts:

```bash
./build_macos.sh release
```

3) Archive and upload with your normal CI/CD flow after the build passes.

## Team Default Rule

Avoid `flutter clean` unless you are already in the full reset branch above.
