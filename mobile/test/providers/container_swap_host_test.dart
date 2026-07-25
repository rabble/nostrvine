// ABOUTME: Tests ContainerSwapHost swaps the live container in place and
// ABOUTME: disposes the previous one after the frame.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/container_swap_host.dart';

final _valueProvider = Provider<String>((_) => 'default');

void main() {
  ProviderContainer containerWith(String value) => ProviderContainer(
    overrides: [_valueProvider.overrideWithValue(value)],
  );

  testWidgets('renders the initial container', (tester) async {
    final controller = AccountSwitchController();
    await tester.pumpWidget(
      ContainerSwapHost(
        initialContainer: containerWith('A'),
        controller: controller,
        child: const _ValueText(),
      ),
    );

    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('swap mounts the new container in place', (tester) async {
    final controller = AccountSwitchController();
    await tester.pumpWidget(
      ContainerSwapHost(
        initialContainer: containerWith('A'),
        controller: controller,
        child: const _ValueText(),
      ),
    );
    expect(find.text('A'), findsOneWidget);

    await controller.swapTo(containerWith('B'));
    await tester.pump();

    expect(find.text('B'), findsOneWidget);
    expect(find.text('A'), findsNothing);
  });

  testWidgets('the previous container is disposed after the swap', (
    tester,
  ) async {
    final controller = AccountSwitchController();
    final first = containerWith('A');
    await tester.pumpWidget(
      ContainerSwapHost(
        initialContainer: first,
        controller: controller,
        child: const _ValueText(),
      ),
    );

    await controller.swapTo(containerWith('B'));
    await tester.pump();

    // A disposed container throws when read.
    expect(() => first.read(_valueProvider), throwsStateError);
  });

  testWidgets('swapTo before mount throws', (tester) async {
    final controller = AccountSwitchController();
    expect(controller.isReady, isFalse);
    expect(() => controller.swapTo(containerWith('X')), throwsStateError);
  });

  testWidgets('controller detaches when the host is disposed', (tester) async {
    final controller = AccountSwitchController();
    await tester.pumpWidget(
      ContainerSwapHost(
        initialContainer: containerWith('A'),
        controller: controller,
        child: const _ValueText(),
      ),
    );
    expect(controller.isReady, isTrue);

    await tester.pumpWidget(const SizedBox());

    expect(controller.isReady, isFalse);
  });
}

class _ValueText extends ConsumerWidget {
  const _ValueText();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(ref.watch(_valueProvider)),
    );
  }
}
