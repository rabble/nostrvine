import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/routes/route_extras.dart';

void main() {
  group('extraAs', () {
    test('returns the value when it already is the requested type', () {
      const extra = CuratedListRouteExtra(listName: 'Favourites');

      expect(extraAs<CuratedListRouteExtra>(extra), same(extra));
    });

    test('returns null for a restored Map instead of throwing (the route '
        'restoration / deep-link crash)', () {
      // After restoration or a deep link GoRouter hands `extra` back as a
      // plain Map<String, dynamic>, not the typed object. A raw `as` cast
      // throws here (Crashlytics 5b96bfc6… / efec8882…); the guard must
      // return null so the route falls back gracefully.
      final restored = <String, dynamic>{
        'listName': 'Favourites',
        'videoIds': <String>['a', 'b'],
      };

      expect(extraAs<CuratedListRouteExtra>(restored), isNull);
    });

    test('reads a restored Map when the caller asks for a Map', () {
      final restored = <String, dynamic>{
        'displayName': 'Ada',
        'avatarUrl': null,
      };

      final map = extraAs<Map<String, dynamic>>(restored);

      expect(map, same(restored));
      expect(map?['displayName'] as String?, 'Ada');
      expect(map?['avatarUrl'] as String?, isNull);
    });

    test('returns null for a scalar-type mismatch', () {
      expect(extraAs<String>(<String, dynamic>{'a': 1}), isNull);
      expect(extraAs<String>('hint'), 'hint');
    });

    test('returns null for a null payload', () {
      expect(extraAs<CuratedListRouteExtra>(null), isNull);
    });
  });

  group('restored map values', () {
    test('reads only string profile hints', () {
      final restored = <String, dynamic>{'displayName': 'Ada', 'avatarUrl': 42};

      expect(extraStringValue(restored, 'displayName'), 'Ada');
      expect(extraStringValue(restored, 'avatarUrl'), isNull);
      expect(extraStringValue(null, 'displayName'), isNull);
    });

    test('reads only boolean editor options', () {
      expect(
        extraBoolValue(<String, dynamic>{'fromLibrary': true}, 'fromLibrary'),
        isTrue,
      );
      expect(
        extraBoolValue(<String, dynamic>{'fromLibrary': 'true'}, 'fromLibrary'),
        isNull,
      );
      expect(extraBoolValue(const <String, dynamic>{}, 'fromLibrary'), isNull);
    });
  });
}
