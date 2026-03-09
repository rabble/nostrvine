// ABOUTME: Stub implementation for js package when not on web platform
// ABOUTME: Provides empty implementations to prevent compilation errors on mobile

// ignore_for_file: avoid_unused_constructor_parameters

// Stub implementations for non-web platforms
class JS {
  const JS([String? name]);
}

class _JSAnonymous {
  const _JSAnonymous();
}

const anonymous = _JSAnonymous();

// Stub function implementations
T allowInterop<T extends Function>(T f) => f;
Function allowInteropCaptureThis(Function f) => f;
