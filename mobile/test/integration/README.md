# Mocked Integration Tests

Tests in this directory exercise multi-step flows using mocked or in-memory
dependencies. They run with plain `flutter test` and require no real backend
services.

```bash
flutter test test/integration/
```

## History

Live-endpoint tests that hit production/staging servers were removed in #2527.
Backend coverage for those paths is tracked in #3052-#3056.

Reorganization of these mocked tests into feature-specific subdirectories under
`test/` is tracked in #2891.

## flutter_test_config.dart

The local `flutter_test_config.dart` runs `testMain()` without initializing
`TestWidgetsFlutterBinding`, which prevents binding conflicts with tests that
set up their own binding.
