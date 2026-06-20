import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(NIP71VideoKinds, () {
    test('subtitleEventKind is 39307', () {
      expect(NIP71VideoKinds.subtitleEventKind, equals(39307));
    });
  });
}
