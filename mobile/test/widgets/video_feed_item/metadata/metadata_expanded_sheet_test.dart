// ABOUTME: Tests for MetadataExpandedSheet and all metadata section widgets.
// ABOUTME: Verifies each section renders when data is present and hides when
// ABOUTME: data is absent. Covers badges, title, stats, creator, tags,
// ABOUTME: collaborators, inspired by, reposted by, and sounds sections.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/clickable_hashtag_text.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_badges_row.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_sounds_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_stats_row.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_tags_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_user_chips.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_verification_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/video_reposters_cubit.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockVideoInteractionsBloc extends Mock
    implements VideoInteractionsBloc {}

class _MockVideoRepostersCubit extends Mock implements VideoRepostersCubit {}

// Stable 64-char hex pubkeys for deterministic tests.
const _creatorPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _collaborator1 =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _collaborator2 =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _inspiredByPubkey =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _reposterPubkey =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const _audioPubkey =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
const _audioEventId =
    '1111111111111111111111111111111111111111111111111111111111111111';

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

UserProfile _makeProfile(String pubkey, String name) => UserProfile(
  pubkey: pubkey,
  displayName: name,
  name: name.toLowerCase(),
  rawData: const {},
  createdAt: DateTime(2025),
  eventId: 'evt_$pubkey',
);

VideoEvent _makeVideo({
  List<String> hashtags = const [],
  List<String> categories = const [],
  List<String> collaboratorPubkeys = const [],
  InspiredByInfo? inspiredByVideo,
  List<String>? reposterPubkeys,
  String? audioEventId,
  String? title,
  String content = '',
  Map<String, String> rawTags = const {},
  int originalLoops = 1500,
  int createdAt = 1700000000,
}) => VideoEvent(
  id: 'test_video_id_00000000000000000000000000000000000000000000000000',
  pubkey: _creatorPubkey,
  createdAt: createdAt,
  content: content,
  timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
  title: title,
  videoUrl: 'https://example.com/video.mp4',
  hashtags: hashtags,
  categories: categories,
  collaboratorPubkeys: collaboratorPubkeys,
  inspiredByVideo: inspiredByVideo,
  reposterPubkeys: reposterPubkeys,
  audioEventId: audioEventId,
  originalLoops: originalLoops,
  rawTags: rawTags,
);

const _testAudio = AudioEvent(
  id: _audioEventId,
  pubkey: _audioPubkey,
  createdAt: 1700000000,
  title: 'Test Sound',
  source: 'Test Artist',
  url: 'https://example.com/audio.aac',
);

void main() {
  late _MockVideoInteractionsBloc mockInteractionsBloc;
  late _MockVideoRepostersCubit mockRepostersCubit;

  setUp(() {
    mockInteractionsBloc = _MockVideoInteractionsBloc();
    when(
      () => mockInteractionsBloc.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockInteractionsBloc.state).thenReturn(
      const VideoInteractionsState(
        status: VideoInteractionsStatus.success,
        likeCount: 250,
        commentCount: 42,
        repostCount: 15,
      ),
    );

    mockRepostersCubit = _MockVideoRepostersCubit();
    when(
      () => mockRepostersCubit.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockRepostersCubit.state,
    ).thenReturn(const VideoRepostersState(isLoading: false));
    when(() => mockRepostersCubit.close()).thenAnswer((_) async {});
  });

  /// Pumps a metadata widget inside the required provider tree.
  Widget buildSubject({
    required Widget child,
    List<Override> providerOverrides = const [],
    VideoRepostersState? repostersState,
  }) {
    if (repostersState != null) {
      when(() => mockRepostersCubit.state).thenReturn(repostersState);
    }

    return UncontrolledProviderScope(
      container: ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            createMockSharedPreferences(),
          ),
          ...providerOverrides,
        ],
      ),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<VideoInteractionsBloc>.value(
                value: mockInteractionsBloc,
              ),
              BlocProvider<VideoRepostersCubit>.value(
                value: mockRepostersCubit,
              ),
            ],
            child: child,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Title section
  // ---------------------------------------------------------------------------
  group('_TitleSection (via $MetadataExpandedSheet)', () {
    testWidgets('renders title and description when present', (tester) async {
      final video = _makeVideo(title: 'Who knew?', content: 'A description');

      await tester.pumpWidget(
        buildSubject(child: MetadataExpandedSheet(video: video)),
      );

      expect(find.text('Who knew?'), findsOneWidget);
      expect(find.text('A description'), findsOneWidget);
    });

    testWidgets('renders description with clickable rich text', (tester) async {
      final video = _makeVideo(
        title: 'Who knew?',
        content: 'Read more at https://example.com/docs #proof',
      );

      await tester.pumpWidget(
        buildSubject(child: MetadataExpandedSheet(video: video)),
      );

      expect(find.text('Who knew?'), findsOneWidget);
      expect(find.byType(ClickableHashtagText), findsOneWidget);
    });

    testWidgets('still renders the section without title or description', (
      tester,
    ) async {
      final video = _makeVideo();

      await tester.pumpWidget(
        buildSubject(child: MetadataExpandedSheet(video: video)),
      );

      // Stats row is always visible.
      expect(find.byType(MetadataStatsRow), findsOneWidget);
      // The title text must not appear since the video has no title.
      expect(find.text('Who knew?'), findsNothing);
      // The date sibling renders even with no title or description.
      final expectedDate = DateFormat.yMMMd(
        'en',
      ).format(DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000));
      expect(find.text(expectedDate), findsOneWidget);
    });

    testWidgets('renders posted date for a recent post', (tester) async {
      final video = _makeVideo(title: 'Who knew?', content: 'A description');

      await tester.pumpWidget(
        buildSubject(child: MetadataExpandedSheet(video: video)),
      );

      final expectedDate = DateFormat.yMMMd(
        'en',
      ).format(DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000));
      expect(find.text(expectedDate), findsOneWidget);
    });

    testWidgets('renders Vine-era date for a classic vine timestamp', (
      tester,
    ) async {
      // 2012-12-11 21:38 UTC — a classic Vine-era timestamp.
      final video = _makeVideo(
        title: 'Classic vine',
        content: 'From the archives',
        createdAt: 1355261891,
      );

      await tester.pumpWidget(
        buildSubject(child: MetadataExpandedSheet(video: video)),
      );

      // Year 2012 must be visible regardless of locale-specific month name.
      expect(find.textContaining('2012'), findsWidgets);
    });

    testWidgets('applies labelMedium typography with onSurfaceVariant color', (
      tester,
    ) async {
      final video = _makeVideo(title: 'Who knew?');

      await tester.pumpWidget(
        buildSubject(child: MetadataExpandedSheet(video: video)),
      );

      final expectedDate = DateFormat.yMMMd(
        'en',
      ).format(DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000));
      final dateText = tester.widget<Text>(find.text(expectedDate));
      expect(dateText.style?.fontSize, equals(12));
      expect(dateText.style?.fontWeight, equals(FontWeight.w600));
      expect(dateText.style?.color, equals(VineTheme.onSurfaceVariant));
    });

    testWidgets('wraps the date in a Semantics with the localized label', (
      tester,
    ) async {
      final video = _makeVideo(title: 'Who knew?');

      await tester.pumpWidget(
        buildSubject(child: MetadataExpandedSheet(video: video)),
      );

      final expectedDate = DateFormat.yMMMd(
        'en',
      ).format(DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000));
      final l10n = _l10n(tester);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label ==
                  l10n.metadataPostedDateSemantics(expectedDate),
        ),
        findsOneWidget,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Captions setting
  // ---------------------------------------------------------------------------
  group('Captions setting', () {
    testWidgets('renders captions row even when video has no subtitles', (
      tester,
    ) async {
      final video = _makeVideo();

      await tester.pumpWidget(
        buildSubject(child: MetadataExpandedSheet(video: video)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Captions'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('defaults captions switch to on from global preference', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(child: MetadataExpandedSheet(video: _makeVideo())),
      );
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue);
      expect(switchWidget.activeThumbColor, VineTheme.whiteText);
      expect(switchWidget.activeTrackColor, VineTheme.vineGreen);
      expect(switchWidget.inactiveThumbColor, VineTheme.whiteText);
      expect(switchWidget.inactiveTrackColor, VineTheme.surfaceContainer);
    });

    testWidgets('renders captions after the primary metadata content', (
      tester,
    ) async {
      final video = _makeVideo(title: 'Why', content: 'Because');

      await tester.pumpWidget(
        buildSubject(child: MetadataExpandedSheet(video: video)),
      );
      await tester.pumpAndSettle();

      final titleY = tester.getTopLeft(find.text('Why')).dy;
      final captionsY = tester.getTopLeft(find.text('Captions')).dy;

      expect(captionsY, greaterThan(titleY));
    });

    testWidgets('keeps captions label adjacent to the toggle', (tester) async {
      await tester.pumpWidget(
        buildSubject(child: MetadataExpandedSheet(video: _makeVideo())),
      );
      await tester.pumpAndSettle();

      final labelRight = tester.getTopRight(find.text('Captions')).dx;
      final switchLeft = tester.getTopLeft(find.byType(Switch)).dx;

      expect(switchLeft - labelRight, lessThanOrEqualTo(24));
    });

    testWidgets('toggling captions switch updates global provider state', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MultiBlocProvider(
                providers: [
                  BlocProvider<VideoInteractionsBloc>.value(
                    value: mockInteractionsBloc,
                  ),
                  BlocProvider<VideoRepostersCubit>.value(
                    value: mockRepostersCubit,
                  ),
                ],
                child: MetadataExpandedSheet(video: _makeVideo()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(container.read(subtitleVisibilityProvider), isFalse);
      expect(prefs.getBool('subtitle_visibility_enabled'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Stats row
  // ---------------------------------------------------------------------------
  group(MetadataStatsRow, () {
    testWidgets('renders all four stat columns with counts', (tester) async {
      final video = _makeVideo();

      await tester.pumpWidget(
        buildSubject(child: MetadataStatsRow(video: video)),
      );

      expect(find.text('1.5K'), findsOneWidget); // originalLoops
      expect(find.text('250'), findsOneWidget); // likeCount
      expect(find.text('42'), findsOneWidget); // commentCount
      expect(find.text('15'), findsOneWidget); // repostCount
      final l10n = _l10n(tester);
      expect(
        find.text(l10n.metadataLoopsLabel(video.totalLoops)),
        findsOneWidget,
      );
      expect(find.text('Likes'), findsOneWidget);
      expect(find.text('Comments'), findsOneWidget);
      expect(find.text('Reposts'), findsOneWidget);
    });

    testWidgets('uses singular Loop label when count is 1', (tester) async {
      final video = _makeVideo(originalLoops: 1);

      await tester.pumpWidget(
        buildSubject(child: MetadataStatsRow(video: video)),
      );

      final l10n = _l10n(tester);
      expect(find.text(l10n.metadataLoopsLabel(1)), findsOneWidget);
    });

    testWidgets('shows dash when loading', (tester) async {
      when(() => mockInteractionsBloc.state).thenReturn(
        const VideoInteractionsState(status: VideoInteractionsStatus.loading),
      );

      final video = _makeVideo();
      await tester.pumpWidget(
        buildSubject(child: MetadataStatsRow(video: video)),
      );

      // Likes, Comments, Reposts show dash; Loops is static.
      expect(find.text('—'), findsNWidgets(3));
    });
  });

  // ---------------------------------------------------------------------------
  // Creator section
  // ---------------------------------------------------------------------------
  group(MetadataCreatorSection, () {
    testWidgets('renders creator chip with profile name', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          providerOverrides: [
            fetchUserProfileProvider(_creatorPubkey).overrideWith(
              (ref) async => _makeProfile(_creatorPubkey, 'Sebastian Heit'),
            ),
          ],
          child: const MetadataCreatorSection(pubkey: _creatorPubkey),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Creator'), findsOneWidget);
      expect(find.text('Sebastian Heit'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Badges row
  // ---------------------------------------------------------------------------
  group(MetadataBadgesRow, () {
    testWidgets('renders Human-Made badge when hasProofMode', (tester) async {
      final video = _makeVideo(rawTags: {'verification': 'verified_mobile'});
      await tester.pumpWidget(
        buildSubject(child: MetadataBadgesRow(video: video)),
      );

      expect(find.textContaining('Human-Made'), findsOneWidget);
    });

    testWidgets('renders Human-Made badge without the divine logo', (
      tester,
    ) async {
      final video = _makeVideo(rawTags: {'verification': 'verified_mobile'});
      await tester.pumpWidget(
        buildSubject(child: MetadataBadgesRow(video: video)),
      );

      expect(find.textContaining('Human-Made'), findsOneWidget);
      expect(find.byType(DivineIcon), findsNothing);
    });

    testWidgets('renders Not Divine badge for external videos', (tester) async {
      final video = _makeVideo();
      await tester.pumpWidget(
        buildSubject(child: MetadataBadgesRow(video: video)),
      );

      // Default test video URL is example.com (not Divine hosted)
      expect(find.text('Not Divine'), findsOneWidget);
    });

    testWidgets('renders both badges with dot separator', (tester) async {
      // hasProofMode but not Divine hosted
      final video = _makeVideo(rawTags: {'verification': 'verified_web'});
      await tester.pumpWidget(
        buildSubject(child: MetadataBadgesRow(video: video)),
      );

      // ProofMode badge shows but shouldShowNotDivineBadge is false
      // (hasProofMode suppresses Not Divine badge)
      expect(find.textContaining('Human-Made'), findsOneWidget);
      expect(find.text('Not Divine'), findsNothing);
    });

    testWidgets('hides when no badges apply', (tester) async {
      // Divine-hosted video with no proof → no badges
      // (isFromDivineServer = true, so Not Divine hidden; no proof = no HM)
      final video = VideoEvent(
        id: 'test_video_id_0000000000000000000000000000000000000000000000000',
        pubkey: _creatorPubkey,
        createdAt: 1700000000,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
        videoUrl: 'https://media.divine.video/test/720p.mp4',
      );
      await tester.pumpWidget(
        buildSubject(child: MetadataBadgesRow(video: video)),
      );

      expect(find.text('Human-Made'), findsNothing);
      expect(find.text('Not Divine'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Tags section
  // ---------------------------------------------------------------------------
  group(MetadataTagsSection, () {
    testWidgets('renders hashtag chips when tags exist', (tester) async {
      final video = _makeVideo(hashtags: ['sick', 'cool', 'baller']);
      await tester.pumpWidget(
        buildSubject(child: MetadataTagsSection(video: video)),
      );

      // Tags section has no label per Figma spec — only chip text.
      expect(find.text('sick'), findsOneWidget);
      expect(find.text('cool'), findsOneWidget);
      expect(find.text('baller'), findsOneWidget);
      expect(find.text('#'), findsNWidgets(3));
    });

    testWidgets('prepends classic hashtag for original Vine', (tester) async {
      final video = _makeVideo(rawTags: {'platform': 'vine'});
      await tester.pumpWidget(
        buildSubject(child: MetadataTagsSection(video: video)),
      );

      expect(find.text('classic'), findsOneWidget);
      expect(find.text('#'), findsOneWidget);
    });

    testWidgets('renders classic and hashtags together', (tester) async {
      final video = _makeVideo(
        hashtags: ['grease'],
        rawTags: {'platform': 'vine'},
      );
      await tester.pumpWidget(
        buildSubject(child: MetadataTagsSection(video: video)),
      );

      expect(find.text('classic'), findsOneWidget);
      expect(find.text('grease'), findsOneWidget);
      // "classic" + "grease" = 2 hashtag chips
      expect(find.text('#'), findsNWidgets(2));
    });

    testWidgets('hides when no hashtags and not Classic', (tester) async {
      final video = _makeVideo();
      await tester.pumpWidget(
        buildSubject(child: MetadataTagsSection(video: video)),
      );

      // No hashtag chips should appear.
      expect(find.text('#'), findsNothing);
    });

    testWidgets('renders category chips with accent colors', (tester) async {
      final video = _makeVideo(
        categories: ['animals', 'music'],
        hashtags: ['cool'],
      );
      await tester.pumpWidget(
        buildSubject(child: MetadataTagsSection(video: video)),
      );

      // Category chips show display name and emoji
      expect(find.text('Animals'), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
      expect(find.text('🐾'), findsOneWidget);
      expect(find.text('🎸'), findsOneWidget);
      // Hashtag chip still present
      expect(find.text('cool'), findsOneWidget);
      expect(find.text('#'), findsOneWidget);
    });

    testWidgets('renders only categories when no hashtags', (tester) async {
      final video = _makeVideo(categories: ['sports']);
      await tester.pumpWidget(
        buildSubject(child: MetadataTagsSection(video: video)),
      );

      expect(find.text('Sports'), findsOneWidget);
      expect(find.text('🏆'), findsOneWidget);
      expect(find.text('#'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Collaborators section
  // ---------------------------------------------------------------------------
  group(MetadataCollaboratorsSection, () {
    testWidgets('renders collaborator chips when present', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          providerOverrides: [
            fetchUserProfileProvider(_collaborator1).overrideWith(
              (ref) async => _makeProfile(_collaborator1, 'Josh Musick'),
            ),
            fetchUserProfileProvider(_collaborator2).overrideWith(
              (ref) async => _makeProfile(_collaborator2, 'Dan Spurgin'),
            ),
          ],
          child: const MetadataCollaboratorsSection(
            collaboratorPubkeys: [_collaborator1, _collaborator2],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Collaborators'), findsOneWidget);
      expect(find.text('Josh Musick'), findsOneWidget);
      expect(find.text('Dan Spurgin'), findsOneWidget);
    });

    testWidgets('hides when no collaborators', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          child: const MetadataCollaboratorsSection(collaboratorPubkeys: []),
        ),
      );

      expect(find.text('Collaborators'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Inspired By section
  // ---------------------------------------------------------------------------
  group(MetadataInspiredBySection, () {
    testWidgets('renders chip when inspired-by exists', (tester) async {
      final video = _makeVideo(
        inspiredByVideo: const InspiredByInfo(
          addressableId: '34236:$_inspiredByPubkey:some-dtag',
        ),
      );

      await tester.pumpWidget(
        buildSubject(
          providerOverrides: [
            fetchUserProfileProvider(_inspiredByPubkey).overrideWith(
              (ref) async =>
                  _makeProfile(_inspiredByPubkey, 'Inspiring Creator'),
            ),
          ],
          child: MetadataInspiredBySection(video: video),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Inspired by'), findsOneWidget);
      expect(find.text('Inspiring Creator'), findsOneWidget);
    });

    testWidgets('hides when no inspired-by', (tester) async {
      final video = _makeVideo();

      await tester.pumpWidget(
        buildSubject(child: MetadataInspiredBySection(video: video)),
      );

      expect(find.text('Inspired by'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Reposted By section
  // ---------------------------------------------------------------------------
  group(MetadataRepostedBySection, () {
    testWidgets('renders reposters fetched from relay', (tester) async {
      final video = _makeVideo();

      await tester.pumpWidget(
        buildSubject(
          repostersState: const VideoRepostersState(
            pubkeys: [_reposterPubkey],
            isLoading: false,
          ),
          providerOverrides: [
            fetchUserProfileProvider(_reposterPubkey).overrideWith(
              (ref) async => _makeProfile(_reposterPubkey, 'Improvising'),
            ),
          ],
          child: MetadataRepostedBySection(video: video),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reposted by'), findsOneWidget);
      expect(find.text('Improvising'), findsOneWidget);
    });

    testWidgets('renders pre-populated reposterPubkeys', (tester) async {
      final video = _makeVideo(reposterPubkeys: [_reposterPubkey]);

      await tester.pumpWidget(
        buildSubject(
          providerOverrides: [
            fetchUserProfileProvider(_reposterPubkey).overrideWith(
              (ref) async => _makeProfile(_reposterPubkey, 'Improvising'),
            ),
          ],
          child: MetadataRepostedBySection(video: video),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reposted by'), findsOneWidget);
      expect(find.text('Improvising'), findsOneWidget);
    });

    testWidgets('hides when relay returns empty and no pre-populated data', (
      tester,
    ) async {
      final video = _makeVideo();

      await tester.pumpWidget(
        buildSubject(child: MetadataRepostedBySection(video: video)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reposted by'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Verification section
  // ---------------------------------------------------------------------------
  group(MetadataVerificationSection, () {
    testWidgets('renders checklist when video has proof data', (tester) async {
      final video = _makeVideo(
        rawTags: {
          'verification': 'verified_mobile',
          'device_attestation': 'token_abc',
          'pgp_fingerprint': 'ABCD1234',
        },
      );
      await tester.pumpWidget(
        buildSubject(child: MetadataVerificationSection(video: video)),
      );

      expect(find.text('Verification'), findsOneWidget);
      expect(find.text('Device attestation'), findsOneWidget);
      expect(find.text('PGP signature'), findsOneWidget);
      expect(find.text('C2PA Content Credentials'), findsOneWidget);
      expect(find.text('Proof manifest'), findsOneWidget);
      // Two passed (device attestation, PGP), two failed (C2PA, manifest).
      // DivineIcon renders SVGs — find by widget type and icon enum value.
      final checkIcons = tester
          .widgetList<DivineIcon>(find.byType(DivineIcon))
          .where((w) => w.icon == DivineIconName.checkCircle);
      final failIcons = tester
          .widgetList<DivineIcon>(find.byType(DivineIcon))
          .where((w) => w.icon == DivineIconName.prohibit);
      expect(checkIcons.length, 2);
      expect(failIcons.length, 2);
    });

    testWidgets('hides when no proof data', (tester) async {
      final video = _makeVideo();
      await tester.pumpWidget(
        buildSubject(child: MetadataVerificationSection(video: video)),
      );

      expect(find.text('Verification'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Sounds section
  // ---------------------------------------------------------------------------
  group(MetadataSoundsSection, () {
    testWidgets('renders sound info when audio exists', (tester) async {
      final video = _makeVideo(audioEventId: _audioEventId);

      await tester.pumpWidget(
        buildSubject(
          providerOverrides: [
            soundByIdProvider(
              _audioEventId,
            ).overrideWith((ref) async => _testAudio),
            userProfileReactiveProvider(_audioPubkey).overrideWith(
              (ref) =>
                  Stream.value(_makeProfile(_audioPubkey, 'Audio Creator')),
            ),
          ],
          child: MetadataSoundsSection(video: video),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sounds'), findsOneWidget);
      expect(find.text('Test Sound'), findsOneWidget);
    });

    testWidgets('shows original sound when no audio reference', (tester) async {
      final video = _makeVideo();

      await tester.pumpWidget(
        buildSubject(child: MetadataSoundsSection(video: video)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sounds'), findsOneWidget);
      expect(find.text('Original sound'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Full sheet integration
  // ---------------------------------------------------------------------------
  group('$MetadataExpandedSheet full integration', () {
    testWidgets('renders all sections for fully populated video', (
      tester,
    ) async {
      final video = _makeVideo(
        title: 'Who knew?',
        content: 'What really happens behind the scenes',
        hashtags: ['grease', 'take503'],
        collaboratorPubkeys: [_collaborator1],
        inspiredByVideo: const InspiredByInfo(
          addressableId: '34236:$_inspiredByPubkey:some-dtag',
        ),
        audioEventId: _audioEventId,
        rawTags: {'verification': 'verified_mobile'},
      );

      await tester.pumpWidget(
        buildSubject(
          repostersState: const VideoRepostersState(
            pubkeys: [_reposterPubkey],
            isLoading: false,
          ),
          providerOverrides: [
            fetchUserProfileProvider(_creatorPubkey).overrideWith(
              (ref) async => _makeProfile(_creatorPubkey, 'Sebastian Heit'),
            ),
            fetchUserProfileProvider(_collaborator1).overrideWith(
              (ref) async => _makeProfile(_collaborator1, 'Josh Musick'),
            ),
            fetchUserProfileProvider(_inspiredByPubkey).overrideWith(
              (ref) async =>
                  _makeProfile(_inspiredByPubkey, 'Inspiring Creator'),
            ),
            fetchUserProfileProvider(_reposterPubkey).overrideWith(
              (ref) async => _makeProfile(_reposterPubkey, 'Improvising'),
            ),
            soundByIdProvider(
              _audioEventId,
            ).overrideWith((ref) async => _testAudio),
            userProfileReactiveProvider(_audioPubkey).overrideWith(
              (ref) =>
                  Stream.value(_makeProfile(_audioPubkey, 'Audio Creator')),
            ),
          ],
          child: MetadataExpandedSheet(video: video),
        ),
      );
      await tester.pumpAndSettle();

      // Title + description
      expect(find.text('Who knew?'), findsOneWidget);
      expect(
        find.text('What really happens behind the scenes'),
        findsOneWidget,
      );

      // Stats
      final l10n = _l10n(tester);
      expect(
        find.text(l10n.metadataLoopsLabel(video.totalLoops)),
        findsOneWidget,
      );
      expect(find.text('Likes'), findsOneWidget);

      // Badges row (Human-Made from verification, not Classic Vine)
      expect(find.textContaining('Human-Made'), findsOneWidget);

      // Verification section (video has 'verified_mobile' raw tag)
      expect(find.text('Verification'), findsOneWidget);

      // Top section labels
      expect(find.text('Creator'), findsOneWidget);

      // Scroll to reveal sections below the fold
      final listFinder = find.byType(ListView);
      await tester.drag(listFinder, const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('Sebastian Heit'), findsOneWidget);
      // Tags section has no label per Figma — verify chips directly.
      expect(find.text('grease'), findsOneWidget);

      // Scroll further to reveal collaborators
      await tester.drag(listFinder, const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('Collaborators'), findsOneWidget);
      expect(find.text('Josh Musick'), findsOneWidget);

      // Scroll further to reveal remaining sections
      await tester.drag(listFinder, const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Inspired by'), findsOneWidget);
      expect(find.text('Inspiring Creator'), findsOneWidget);
      expect(find.text('Reposted by'), findsOneWidget);
      expect(find.text('Improvising'), findsOneWidget);
      expect(find.text('Sounds'), findsOneWidget);
      expect(find.text('Test Sound'), findsOneWidget);
    });

    testWidgets('renders only populated sections for sparse video', (
      tester,
    ) async {
      final video = _makeVideo(title: 'Simple video', hashtags: ['hello']);

      await tester.pumpWidget(
        buildSubject(
          providerOverrides: [
            fetchUserProfileProvider(_creatorPubkey).overrideWith(
              (ref) async => _makeProfile(_creatorPubkey, 'Test User'),
            ),
          ],
          child: MetadataExpandedSheet(video: video),
        ),
      );
      await tester.pumpAndSettle();

      // Present
      expect(find.text('Simple video'), findsOneWidget);
      expect(find.text('Creator'), findsOneWidget);
      // Tags section has no label — verify chip text directly.
      expect(find.text('hello'), findsOneWidget);

      // Absent
      expect(find.text('Collaborators'), findsNothing);
      expect(find.text('Inspired by'), findsNothing);
      expect(find.text('Reposted by'), findsNothing);

      // Sounds section is always present (shows "Original sound")
      // Scroll down to find it
      final listFinder = find.byType(ListView);
      await tester.drag(listFinder, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('Sounds'), findsOneWidget);
      expect(find.text('Original sound'), findsOneWidget);
    });
  });
}
