import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/community_content_label_provider.dart';
import 'package:openvine/repositories/community_content_label_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/video_feed_item/actions/help_classify_action_button.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_button.dart';

class _MockRepository extends Mock implements CommunityContentLabelRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockVideoEvent extends Mock implements VideoEvent {}

void main() {
  group(HelpClassifyActionButton, () {
    late _MockRepository repository;
    late _MockAuthService auth;
    late _MockVideoEvent video;
    late AppLocalizations l10n;
    const myPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    setUpAll(() {
      registerFallbackValue(_MockVideoEvent());
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    setUp(() {
      repository = _MockRepository();
      auth = _MockAuthService();
      video = _MockVideoEvent();
      when(() => auth.currentPublicKeyHex).thenReturn(myPubkey);
      when(
        () => repository.mySuggestedLabels(any(), any()),
      ).thenAnswer((_) async => <String>{});
    });

    Widget wrap({CommunityContentLabelRepository? repo}) => ProviderScope(
      overrides: [
        communityContentLabelRepositoryProvider.overrideWithValue(repo),
        authServiceProvider.overrideWithValue(auth),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: HelpClassifyActionButton(video: video)),
      ),
    );

    testWidgets('renders the action when the repository is ready', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(repo: repository));
      await tester.pumpAndSettle();

      expect(find.byType(VideoActionButton), findsOneWidget);
    });

    testWidgets('renders nothing until the repository is ready', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.byType(VideoActionButton), findsNothing);
    });

    testWidgets('renders nothing when there is no signed-in pubkey', (
      tester,
    ) async {
      when(() => auth.currentPublicKeyHex).thenReturn(null);

      await tester.pumpWidget(wrap(repo: repository));
      await tester.pumpAndSettle();

      expect(find.byType(VideoActionButton), findsNothing);
    });

    testWidgets('opens the suggestion sheet when tapped', (tester) async {
      await tester.pumpWidget(wrap(repo: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(VideoActionButton));
      await tester.pumpAndSettle();

      expect(find.text(l10n.communitySuggestTitle), findsOneWidget);
    });
  });
}
