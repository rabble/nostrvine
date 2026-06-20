import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/subtitle_editor/subtitle_editor_screen.dart';
import 'package:openvine/widgets/video_metadata/modes/edit/video_metadata_edit_bottom_bar.dart';

import '../../../../helpers/go_router.dart';
import '../../../../helpers/test_helpers.dart';

void main() {
  group(VideoMetadataEditBottomBar, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late VideoEvent testVideo;

    setUpAll(() {
      registerFallbackValue(TestHelpers.createVideoEvent(id: 'fallback'));
    });

    setUp(() {
      testVideo = TestHelpers.createVideoEvent(
        id: '0000000000000000000000000000000000000000000000000000000000000000',
      );
    });

    Widget buildSubject(MockGoRouter goRouter) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MockGoRouterProvider(
              goRouter: goRouter,
              child: VideoMetadataEditBottomBar(
                video: testVideo,
                initialCollaboratorPubkeys: const {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('navigates to subtitle editor when tapped', (tester) async {
      final mockGoRouter = MockGoRouter();
      when(
        () => mockGoRouter.push<Object?>(any(), extra: any(named: 'extra')),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(buildSubject(mockGoRouter));

      await tester.tap(find.text(l10n.videoEditEditSubtitles));
      await tester.pump();

      verify(
        () => mockGoRouter.push<Object?>(
          SubtitleEditorScreen.pathFor(testVideo.id),
          extra: testVideo,
        ),
      ).called(1);
    });
  });
}
