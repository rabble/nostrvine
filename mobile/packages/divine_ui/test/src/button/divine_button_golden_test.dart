// ABOUTME: Alchemist gallery goldens for DivineButton — one image per axis
// ABOUTME: (types, sizes) covering the visual contract for the design system.

import 'package:alchemist/alchemist.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void _noop() {}

Future<void> main() async {
  await goldenTest(
    'DivineButton — types',
    fileName: 'divine_button_types',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        for (final type in DivineButtonType.values)
          GoldenTestScenario(
            name: type.name,
            child: DivineButton(
              label: type.name,
              type: type,
              onPressed: _noop,
            ),
          ),
        GoldenTestScenario(
          name: 'disabled',
          child: const DivineButton(label: 'disabled', onPressed: null),
        ),
      ],
    ),
  );

  await goldenTest(
    'DivineButton — sizes',
    fileName: 'divine_button_sizes',
    builder: () => GoldenTestGroup(
      columns: 3,
      children: [
        for (final size in DivineButtonSize.values)
          GoldenTestScenario(
            name: size.name,
            child: DivineButton(label: 'Go', size: size, onPressed: _noop),
          ),
      ],
    ),
  );
}
