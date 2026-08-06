// ABOUTME: Tests pull-to-refresh on the standalone bookmarks screen's view
// ABOUTME: Bookmarks lost the profile tab's refresh when they moved off-profile

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_saved_videos/profile_saved_videos_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/saved_videos_screen.dart';
import 'package:openvine/services/video_event_service.dart';

import '../helpers/test_provider_overrides.dart';

class _MockProfileSavedVideosBloc
    extends MockBloc<ProfileSavedVideosEvent, ProfileSavedVideosState>
    implements ProfileSavedVideosBloc {}

class _FakeVideoEventService extends Mock implements VideoEventService {
  @override
  Stream<String> get removedVideoIds => const Stream<String>.empty();
}

void main() {
  group(SavedVideosView, () {
    late _MockProfileSavedVideosBloc mockBloc;

    setUpAll(() {
      registerFallbackValue(const ProfileSavedVideosSyncRequested());
    });

    setUp(() {
      mockBloc = _MockProfileSavedVideosBloc();
    });

    Widget buildSubject() {
      return testProviderScope(
        additionalOverrides: [
          videoEventServiceProvider.overrideWithValue(_FakeVideoEventService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: BlocProvider<ProfileSavedVideosBloc>.value(
              value: mockBloc,
              child: const SavedVideosView(userIdHex: 'test-user'),
            ),
          ),
        ),
      );
    }

    testWidgets('a pull requests a sync the indicator can wait on', (
      tester,
    ) async {
      // Empty is the state a pull most needs to work in: unbookmarking the
      // last video leaves nothing to scroll.
      when(() => mockBloc.state).thenReturn(
        const ProfileSavedVideosState(status: ProfileSavedVideosStatus.success),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 300),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final captured = verify(
        () => mockBloc.add(captureAny<ProfileSavedVideosSyncRequested>()),
      ).captured.cast<ProfileSavedVideosSyncRequested>();

      // A completer is what releases the spinner; without one the indicator
      // would spin until it timed out rather than until the sync finished.
      expect(captured, hasLength(1));
      expect(captured.single.completer, isNotNull);

      // Settle the indicator so the test does not end mid-animation.
      captured.single.completer!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('does not sync without a pull', (tester) async {
      when(() => mockBloc.state).thenReturn(
        const ProfileSavedVideosState(status: ProfileSavedVideosStatus.success),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      verifyNever(
        () => mockBloc.add(any<ProfileSavedVideosSyncRequested>()),
      );
    });
  });
}
