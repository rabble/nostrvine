import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_feed_item/inspired_by_attribution_row.dart';

void main() {
  const firstCreator =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const secondCreator =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

  testWidgets('renders compact count for multiple clip source credits', (
    tester,
  ) async {
    final video = VideoEvent(
      id: 'video-id',
      pubkey:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      createdAt: 1757385263,
      content: 'Test video',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263000),
      videoUrl: 'https://cdn.example.com/video.mp4',
      clipSourceCredits: const [
        ClipSourceCredit(
          authorPubkey: firstCreator,
          addressableId: '34236:$firstCreator:first',
        ),
        ClipSourceCredit(
          authorPubkey: secondCreator,
          addressableId: '34236:$secondCreator:second',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InspiredByAttributionRow(video: video, isActive: true),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel(RegExp(r'Inspired by .*\+1')), findsOneWidget);
    expect(find.textContaining('+1'), findsOneWidget);
  });
}
