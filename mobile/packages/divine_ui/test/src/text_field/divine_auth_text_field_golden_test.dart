// ABOUTME: Alchemist gallery golden for DivineAuthTextField states.

import 'package:alchemist/alchemist.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> main() async {
  await goldenTest(
    'DivineAuthTextField — states',
    fileName: 'divine_auth_text_field_states',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'default',
          child: const SizedBox(
            width: 320,
            child: DivineAuthTextField(label: 'Email'),
          ),
        ),
        GoldenTestScenario(
          name: 'disabled',
          child: const SizedBox(
            width: 320,
            child: DivineAuthTextField(label: 'Email', enabled: false),
          ),
        ),
      ],
    ),
  );
}
