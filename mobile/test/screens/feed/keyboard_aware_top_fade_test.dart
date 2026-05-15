// ABOUTME: Tests for KeyboardAwareTopFade — the ShaderMask wrapper that
// ABOUTME: fades the top of the fullscreen action column while the keyboard
// ABOUTME: is up, so the Like button doesn't sit under the AppBar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';

void main() {
  group(KeyboardAwareTopFade, () {
    // KeyboardAwareTopFade reads keyboard visibility off the underlying
    // FlutterView (not MediaQuery) and rebuilds via
    // WidgetsBindingObserver.didChangeMetrics — Scaffold strips
    // viewInsets from its body's MediaQuery, so the FlutterView is the
    // only source of truth. Drive the tests the same way the real
    // platform would: by setting `tester.view.viewInsets`.

    const subject = Directionality(
      textDirection: TextDirection.ltr,
      child: KeyboardAwareTopFade(
        child: SizedBox(
          key: ValueKey('child'),
          width: 48,
          height: 200,
        ),
      ),
    );

    testWidgets('passes the child through with no ShaderMask when the '
        'keyboard is hidden (viewInsets.bottom == 0)', (tester) async {
      tester.view.viewInsets = FakeViewPadding.zero;
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(subject);

      expect(find.byType(ShaderMask), findsNothing);
      expect(find.byKey(const ValueKey('child')), findsOneWidget);
    });

    testWidgets('wraps the child in a ShaderMask when the keyboard '
        'is visible (viewInsets.bottom > 0)', (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(subject);

      expect(find.byType(ShaderMask), findsOneWidget);
      expect(find.byKey(const ValueKey('child')), findsOneWidget);
    });

    testWidgets('rebuilds and removes the ShaderMask when the keyboard '
        'closes', (tester) async {
      addTearDown(tester.view.resetViewInsets);

      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpWidget(subject);
      expect(find.byType(ShaderMask), findsOneWidget);

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets(
      'uses BlendMode.dstIn so the gradient acts as an alpha mask',
      (tester) async {
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);

        await tester.pumpWidget(subject);

        final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));
        expect(mask.blendMode, BlendMode.dstIn);
      },
    );
  });
}
