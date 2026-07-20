// ABOUTME: Golden tests for UserAvatar covering placeholder tone variety + sizes.
// ABOUTME: Alchemist CI goldens (platform-agnostic) so they gate CI inline.

import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/user_avatar.dart';

void main() {
  group('UserAvatar golden', () {
    // UserAvatar with only name/size always renders its deterministic gradient
    // placeholder (rune-sum tone hash) — no network image, no async decode —
    // so these goldens are stable. Different names produce different tones.
    goldenTest(
      'renders placeholder states',
      fileName: 'user_avatar_states',
      builder: () => GoldenTestGroup(
        columns: 3,
        children: [
          GoldenTestScenario(
            name: 'With name',
            child: const UserAvatar(name: 'John Doe', size: 60),
          ),
          GoldenTestScenario(
            name: 'Empty name',
            child: const UserAvatar(name: '', size: 60),
          ),
          GoldenTestScenario(
            name: 'No name',
            child: const UserAvatar(size: 60),
          ),
          GoldenTestScenario(
            name: 'Single letter',
            child: const UserAvatar(name: 'X', size: 60),
          ),
          GoldenTestScenario(
            name: 'Initial A',
            child: const UserAvatar(name: 'Alice Anderson', size: 60),
          ),
          GoldenTestScenario(
            name: 'Initial Z',
            child: const UserAvatar(name: 'Zack Zimmerman', size: 60),
          ),
        ],
      ),
    );

    goldenTest(
      'renders across sizes',
      fileName: 'user_avatar_sizes',
      builder: () => GoldenTestGroup(
        columns: 4,
        children: [
          GoldenTestScenario(
            name: '20',
            child: const UserAvatar(name: 'User', size: 20),
          ),
          GoldenTestScenario(
            name: '30',
            child: const UserAvatar(name: 'User', size: 30),
          ),
          GoldenTestScenario(
            name: '40',
            child: const UserAvatar(name: 'User', size: 40),
          ),
          GoldenTestScenario(
            name: '60',
            child: const UserAvatar(name: 'User', size: 60),
          ),
          GoldenTestScenario(
            name: '80',
            child: const UserAvatar(name: 'User', size: 80),
          ),
          GoldenTestScenario(
            name: '120',
            child: const UserAvatar(name: 'User', size: 120),
          ),
        ],
      ),
    );
  });
}
