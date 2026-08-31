// ABOUTME: Tests that the account status route is a known route shape and
// ABOUTME: round-trips through parseKnownRoute/buildRoute (s-t-s#200).

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/router/route_paths.dart';

void main() {
  group('account status route', () {
    test('parses to the account status context', () {
      // The `settings` segment validator accepts only an allow-listed set of
      // subpaths, so a new /settings/* path that is not added there is
      // rejected as an unknown route shape.
      final context = parseKnownRoute(RoutePaths.accountStatus);

      expect(context, isNotNull);
      expect(context!.type, RouteType.accountStatus);
    });

    test('builds back to its path', () {
      expect(
        buildRoute(const RouteContext(type: RouteType.accountStatus)),
        RoutePaths.accountStatus,
      );
    });

    test('does not shadow the settings root', () {
      final context = parseKnownRoute(RoutePaths.settings);

      expect(context, isNotNull);
      expect(context!.type, isNot(RouteType.accountStatus));
    });
  });
}
