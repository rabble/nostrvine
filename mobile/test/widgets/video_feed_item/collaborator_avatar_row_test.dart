// ABOUTME: Widget tests for status-aware CollaboratorAvatarRow rendering.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_feed_item/collaborator_avatar_row.dart';

const _creatorPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

VideoEvent _video({List<String> collaborators = const []}) => VideoEvent(
  id: 'test_video_id_00000000000000000000000000000000000000000000000000',
  pubkey: _creatorPubkey,
  createdAt: 1700000000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
  videoUrl: 'https://example.com/video.mp4',
  collaboratorPubkeys: collaborators,
);

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group(CollaboratorAvatarRow, () {
    testWidgets(
      'renders SizedBox.shrink when video has no collaborators',
      (tester) async {
        await tester.pumpWidget(
          _wrap(CollaboratorAvatarRow(video: _video())),
        );
        expect(find.byIcon(Icons.people), findsNothing);
      },
    );
  });
}
