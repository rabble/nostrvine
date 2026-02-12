// ABOUTME: Tests that VideoExploreTile only shows NIP-05 badge for verified users
// ABOUTME: Ensures blue checkmark requires actual DNS verification, not just a claim

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/widgets/video_explore_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testPubkey =
      'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

  late VideoEvent testVideo;

  setUp(() {
    final now = DateTime.now();
    testVideo = VideoEvent(
      id: 'test_event_id_001',
      pubkey: testPubkey,
      content: 'Test video',
      createdAt: now.millisecondsSinceEpoch ~/ 1000,
      timestamp: now,
      videoUrl: 'https://example.com/video.mp4',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      title: 'Test Video',
      duration: 15,
      hashtags: ['test'],
    );
  });

  Widget buildSubject({
    required Nip05VerificationStatus verificationStatus,
    String? nip05,
  }) {
    return ProviderScope(
      overrides: [
        userProfileReactiveProvider.overrideWith(
          (ref, pubkey) async => UserProfile(
            pubkey: pubkey,
            name: 'Test User',
            nip05: nip05,
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: 'test_event',
          ),
        ),
        nip05VerificationProvider.overrideWith(
          (ref, pubkey) async => verificationStatus,
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 300,
            child: VideoExploreTile(video: testVideo, isActive: false),
          ),
        ),
      ),
    );
  }

  group(VideoExploreTile, () {
    group('NIP-05 badge', () {
      testWidgets('shows blue checkmark when NIP-05 is verified', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            verificationStatus: Nip05VerificationStatus.verified,
            nip05: 'alice@example.com',
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.check), findsOneWidget);
      });

      testWidgets('does not show checkmark when NIP-05 verification fails', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            verificationStatus: Nip05VerificationStatus.failed,
            nip05: 'fake@example.com',
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.check), findsNothing);
      });

      testWidgets('does not show checkmark when NIP-05 has network error', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            verificationStatus: Nip05VerificationStatus.error,
            nip05: 'alice@example.com',
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.check), findsNothing);
      });

      testWidgets('does not show checkmark when user has no NIP-05', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(verificationStatus: Nip05VerificationStatus.none),
        );
        await tester.pump();

        expect(find.byIcon(Icons.check), findsNothing);
      });

      testWidgets('does not show checkmark while verification is pending', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            verificationStatus: Nip05VerificationStatus.pending,
            nip05: 'alice@example.com',
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.check), findsNothing);
      });
    });
  });
}
