@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart' show TestOn;

import 'html_video_element_backend_web_test_stub.dart'
    if (dart.library.js_interop) 'html_video_element_backend_web_test_web.dart'
    as platform;

void main() => platform.main();
