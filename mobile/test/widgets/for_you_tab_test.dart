// Pins the For You header's accessibility contract (#6852): the header strip
// is a single labelled button rather than a silent tap region wrapped around a
// second labelled button, and activating it opens the algorithm explainer.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/widgets/for_you_tab.dart';

class _AvailableFunnelcake extends FunnelcakeAvailable {
  @override
  Future<bool> build() async => true;
}

class _EmptyForYouFeed extends ForYouFeed {
  @override
  Future<VideoFeedState> build() async =>
      const VideoFeedState(videos: [], hasMoreContent: false);
}

Widget _host() => ProviderScope(
  overrides: [
    funnelcakeAvailableProvider.overrideWith(_AvailableFunnelcake.new),
    forYouFeedProvider.overrideWith(_EmptyForYouFeed.new),
  ],
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: ForYouTab()),
  ),
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(ForYouTab, () {
    testWidgets('header is one button named by its visible title', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text(l10n.forYouAlgorithmTitle)),
        isSemantics(
          isButton: true,
          label: l10n.forYouAlgorithmTitle,
          hint: l10n.forYouAlgorithmHowItWorksTitle,
        ),
      );

      // The info icon opens the same sheet as the row, so it contributes no
      // node of its own — walking up from it lands on the header's button
      // rather than a second one announcing the same action.
      expect(
        tester.getSemantics(find.byType(DivineIconButton)),
        isSemantics(label: l10n.forYouAlgorithmTitle),
      );

      handle.dispose();
    });

    testWidgets('tapping the header opens the algorithm explainer', (
      tester,
    ) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      // The subtitle renders only inside the explainer sheet, so it proves the
      // sheet opened instead of matching something in the header strip.
      expect(find.text(l10n.forYouAlgorithmSubtitle), findsNothing);

      await tester.tap(find.text(l10n.forYouAlgorithmTitle));
      await tester.pumpAndSettle();

      expect(find.text(l10n.forYouAlgorithmSubtitle), findsOneWidget);
    });
  });
}
