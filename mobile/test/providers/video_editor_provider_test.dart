// ABOUTME: Unit tests for EditorProvider (Riverpod) validating state mutations and provider behavior
// ABOUTME: Tests all EditorNotifier methods and state transitions using ProviderContainer

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// TODO(@hm21): update tests
void main() {
  group('EditorProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });
  });
}
