// ABOUTME: Stub implementation for dart:js_util when not on web platform  
// ABOUTME: Provides empty implementations to prevent compilation errors on mobile

// Stub implementations for non-web platforms
T callMethod<T>(Object object, String method, List<dynamic> args) {
  throw UnsupportedError('JavaScript interop not supported on this platform');
}

T getProperty<T>(Object object, String property) {
  throw UnsupportedError('JavaScript interop not supported on this platform');
}

void setProperty(Object object, String property, dynamic value) {
  throw UnsupportedError('JavaScript interop not supported on this platform');
}

bool hasProperty(Object object, String property) {
  return false;
}

dynamic jsify(Object? object) {
  throw UnsupportedError('JavaScript interop not supported on this platform');
}

T dartify<T>(dynamic object) {
  throw UnsupportedError('JavaScript interop not supported on this platform');
}

Future<T> promiseToFuture<T>(Object jsPromise) {
  throw UnsupportedError('JavaScript interop not supported on this platform');
}