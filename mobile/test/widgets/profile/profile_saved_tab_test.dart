import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:followed_hashtags_repository/followed_hashtags_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_saved_hashtags/profile_saved_hashtags_cubit.dart';
import 'package:openvine/blocs/profile_saved_videos/profile_saved_videos_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/profile/profile_saved_grid.dart';
import 'package:openvine/widgets/profile/profile_saved_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockProfileSavedVideosBloc
    extends MockBloc<ProfileSavedVideosEvent, ProfileSavedVideosState>
    implements ProfileSavedVideosBloc {}

void main() {
  group(ProfileOwnSavedTab, () {
    late _MockProfileSavedVideosBloc mockVideosBloc;

    setUp(() {
      mockVideosBloc = _MockProfileSavedVideosBloc();
      when(() => mockVideosBloc.state).thenReturn(
        const ProfileSavedVideosState(
          status: ProfileSavedVideosStatus.success,
        ),
      );
    });

    testWidgets('defaults to Videos; hashtag empty copy stays offstage', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = FollowedHashtagsRepository(prefs: prefs);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<ProfileSavedVideosBloc>.value(
                  value: mockVideosBloc,
                ),
                BlocProvider<ProfileSavedHashtagsCubit>(
                  create: (_) => ProfileSavedHashtagsCubit(repository: repo),
                ),
              ],
              child: const ProfileOwnSavedTab(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProfileSavedGrid), findsOneWidget);
      expect(find.text(l10n.profileNoFollowedTagsTitle), findsNothing);

      await repo.dispose();
    });

    testWidgets('Tags tab switches visible pane to hashtag grid empty state', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = FollowedHashtagsRepository(prefs: prefs);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<ProfileSavedVideosBloc>.value(
                  value: mockVideosBloc,
                ),
                BlocProvider<ProfileSavedHashtagsCubit>(
                  create: (_) => ProfileSavedHashtagsCubit(repository: repo),
                ),
              ],
              child: const ProfileOwnSavedTab(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.profileSavedFilterTags));
      await tester.pumpAndSettle();

      expect(find.text(l10n.profileNoFollowedTagsTitle), findsOneWidget);

      await repo.dispose();
    });
  });
}
