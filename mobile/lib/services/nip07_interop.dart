// ABOUTME: Dispatches to the stub or web implementation of NIP-07 interop.
// ABOUTME: Public surface (types) is defined in nip07_types.dart.

export 'package:openvine/services/nip07_interop_stub.dart'
    if (dart.library.js_interop) 'package:openvine/services/nip07_interop_web.dart';
export 'package:openvine/services/nip07_types.dart';
