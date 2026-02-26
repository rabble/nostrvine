import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/models/vine_draft.dart';

class MockVineDraft extends Mock implements VineDraft {}

void main() {
  late MockVineDraft draft;

  setUp(() {
    draft = MockVineDraft();
    when(() => draft.id).thenReturn('draft1');
  });

  group('BackgroundPublishState', () {
    test('supports value equality', () {
      const state1 = BackgroundPublishState();
      const state2 = BackgroundPublishState();
      expect(state1, equals(state2));
    });
  });
}
