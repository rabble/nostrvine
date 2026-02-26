// ABOUTME: Main library file for cryptography_flutter plugin override
// ABOUTME: Provides cross-platform cryptography implementations

// Export web implementation when available
export 'cryptography_flutter_web.dart'
    if (dart.library.html) 'cryptography_flutter_web.dart';
