import 'package:content_policy/content_policy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/app_providers.dart';

void main() {
  test('contentPolicyEngineProvider exposes default rule set', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final engine = container.read(contentPolicyEngineProvider);
    expect(engine.rules.first, isA<SelfReferenceRule>());
    expect(engine.rules, hasLength(4));
  });
}
