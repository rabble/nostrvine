import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/startup/divine_material_app.dart';

void main() {
  group('PlatformBrightnessStatusBar', () {
    testWidgets('updates the overlay style when platform brightness changes', (
      tester,
    ) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;

      await tester.pumpWidget(
        const PlatformBrightnessStatusBar(child: SizedBox()),
      );

      SystemUiOverlayStyle overlayStyle() => tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .value;

      expect(overlayStyle(), VineTheme.statusBarStyle);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pump();

      expect(overlayStyle(), VineTheme.lightStatusBarStyle);
    });
  });
}
