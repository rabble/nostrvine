// ABOUTME: Platform-conditional SQLCipher native-runtime bootstrap.
// ABOUTME: Native applies the Android lib override + probes availability; web is a no-op.

export 'sqlcipher_runtime_stub.dart'
    if (dart.library.io) 'sqlcipher_runtime_io.dart';
