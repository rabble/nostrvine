// ABOUTME: Fails if a second RouteType <-> tab map appears anywhere in lib/
// ABOUTME: Eight copies had drifted apart before #3337 collapsed them into one

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A `switch` arm mapping [RouteType.home] to tab 0 — the shape every copy of
/// the tab map had. Deliberately does not match a map literal like
/// `{RouteType.home: 0}`, which `last_tab_position_provider` uses for a
/// different purpose (a remembered scroll index, not a tab index).
final _tabIndexMap = RegExp(
  r'case\s+RouteType\.home\s*:\s*\n\s*return\s+0\b|RouteType\.home\s*=>\s*0\b',
);

/// The reverse map: tab 0 back to [RouteType.home].
final _routeTypeMap = RegExp(
  r'case\s+0\s*:\s*\n\s*return\s+RouteType\.home\b|0\s*=>\s*RouteType\.home\b',
);

const _owner = 'lib/router/navigation/tab_identity.dart';

List<String> _filesMatching(RegExp pattern) =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => pattern.hasMatch(f.readAsStringSync()))
        .map((f) => f.path)
        .toList()
      ..sort();

void main() {
  group('tab identity has exactly one home', () {
    // RouteType.inbox was missing from two of the four RouteType -> tab copies
    // for 162 days, which is what made Android system back close the app from
    // the Inbox tab. A ninth copy would be free to drift the same way.
    test('only tab_identity.dart maps a RouteType to a tab index', () {
      expect(
        _filesMatching(_tabIndexMap),
        equals([_owner]),
        reason:
            'Import tabIndexFromRouteType from $_owner instead of writing a '
            'local switch. Adding a tab means editing one file, not four.',
      );
    });

    test('only tab_identity.dart maps a tab index to a RouteType', () {
      expect(
        _filesMatching(_routeTypeMap),
        equals([_owner]),
        reason:
            'Import routeTypeForTab from $_owner instead of writing a local '
            'switch.',
      );
    });
  });
}
