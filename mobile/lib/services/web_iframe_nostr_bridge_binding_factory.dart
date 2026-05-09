import 'package:openvine/services/web_iframe_nostr_bridge_binding.dart';
import 'package:openvine/services/web_iframe_nostr_bridge_binding_factory_stub.dart'
    if (dart.library.js_interop) 'package:openvine/services/web_iframe_nostr_bridge_binding_factory_web.dart';

WebIframeNostrBridgeBinding createWebIframeNostrBridgeBinding() =>
    createWebIframeNostrBridgeBindingImpl();
