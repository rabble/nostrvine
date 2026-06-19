// ABOUTME: Platform-conditional SQLite3MultipleCiphers runtime bootstrap.
// ABOUTME: Native probes sqlite3mc availability; web is a no-op.

export 'sqlcipher_runtime_stub.dart'
    if (dart.library.io) 'sqlcipher_runtime_io.dart';
