import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:followed_hashtags_repository/followed_hashtags_repository.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/profile/profile_followed_hashtags_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows sorted hashtag tiles when repository has labels', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = FollowedHashtagsRepository(prefs: prefs);
    await repo.addFollowedHashtag('zebra');
    await repo.addFollowedHashtag('apple');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          followedHashtagsRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ProfileFollowedHashtagsGrid()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // [SearchTagChip] shows `#` and tag body as separate [Text] nodes (search parity).
    expect(find.text('apple'), findsOneWidget);
    expect(find.text('zebra'), findsOneWidget);

    await repo.dispose();
  });

  testWidgets('empty state when no followed tags', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = FollowedHashtagsRepository(prefs: prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          followedHashtagsRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ProfileFollowedHashtagsGrid()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No tags saved yet'), findsOneWidget);

    await repo.dispose();
  });
}
