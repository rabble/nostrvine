// ABOUTME: Widget tests for ConversationView
// ABOUTME: Tests 1:1 and group conversation headers, empty state,
// ABOUTME: message input, sender attribution, shared video cards,
// ABOUTME: bubble colors, Kind 15 file messages, and block/report actions

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/inbox/conversation_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

import '../../helpers/go_router.dart';

class _MockConversationBloc
    extends MockBloc<ConversationEvent, ConversationState>
    implements ConversationBloc {}

class _MockContentBlocklistService extends Mock
    implements ContentBlocklistService {}

void main() {
  final testProfile = UserProfile(
    pubkey: 'abc123def456abc123def456abc123def456abc123def456abc123def456abc1',
    displayName: 'Sebastian Heit',
    name: 'sebastianheit',
    nip05: 'sebastian@divine.video',
    rawData: const {},
    createdAt: DateTime.now(),
    eventId:
        'event123456789012345678901234567890123456789012345678901234567890',
  );

  Widget buildSubject({required Widget child}) {
    return MaterialApp(home: child);
  }

  group(ConversationView, () {
    group('1:1 mode', () {
      group('renders', () {
        testWidgets('renders $ConversationView', (tester) async {
          await tester.pumpWidget(
            buildSubject(
              child: ConversationView(
                recipientProfile: testProfile,
                isGroup: false,
                participantCount: 1,
                participantNames: const [],
                userPubkey: '',
              ),
            ),
          );

          expect(find.byType(ConversationView), findsOneWidget);
        });

        testWidgets('renders recipient display name in header', (
          tester,
        ) async {
          await tester.pumpWidget(
            buildSubject(
              child: ConversationView(
                recipientProfile: testProfile,
                isGroup: false,
                participantCount: 1,
                participantNames: const [],
                userPubkey: '',
              ),
            ),
          );

          // Name appears in both header and empty profile card.
          expect(find.text('Sebastian Heit'), findsNWidgets(2));
        });

        testWidgets('renders Divine Moderation Team for moderation pubkey', (
          tester,
        ) async {
          final moderationProfile = UserProfile(
            pubkey: ModerationLabelService.divineModerationPubkeyHex,
            rawData: const {},
            createdAt: DateTime.now(),
            eventId:
                'event123456789012345678901234567890123456789012345678901234567890',
          );

          await tester.pumpWidget(
            buildSubject(
              child: ConversationView(
                recipientProfile: moderationProfile,
                isGroup: false,
                participantCount: 1,
                participantNames: const [],
                userPubkey: '',
              ),
            ),
          );

          // Name appears in both header and empty profile card.
          expect(
            find.text('Divine Moderation Team'),
            findsNWidgets(2),
            reason:
                'TC-025: Moderation pubkey should show '
                '"Divine Moderation Team" in header and profile card',
          );
        });

        testWidgets('does not render nip05 in header', (tester) async {
          await tester.pumpWidget(
            buildSubject(
              child: ConversationView(
                recipientProfile: testProfile,
                isGroup: false,
                participantCount: 1,
                participantNames: const [],
                userPubkey: '',
              ),
            ),
          );

          // Name appears in both header and empty conversation profile card.
          expect(find.text('Sebastian Heit'), findsNWidgets(2));

          // Nip05 appears only in profile card, not in header.
          expect(find.text('@sebastian@divine.video'), findsOneWidget);
        });

        testWidgets('renders back chevron button', (tester) async {
          await tester.pumpWidget(
            buildSubject(
              child: ConversationView(
                recipientProfile: testProfile,
                isGroup: false,
                participantCount: 1,
                participantNames: const [],
                userPubkey: '',
              ),
            ),
          );

          expect(find.byIcon(Icons.chevron_left), findsOneWidget);
        });

        testWidgets('renders more options button', (tester) async {
          await tester.pumpWidget(
            buildSubject(
              child: ConversationView(
                recipientProfile: testProfile,
                isGroup: false,
                participantCount: 1,
                participantNames: const [],
                userPubkey: '',
              ),
            ),
          );

          expect(find.byIcon(Icons.more_horiz), findsOneWidget);
        });

        testWidgets('renders empty conversation profile card', (
          tester,
        ) async {
          await tester.pumpWidget(
            buildSubject(
              child: ConversationView(
                recipientProfile: testProfile,
                isGroup: false,
                participantCount: 1,
                participantNames: const [],
                userPubkey: '',
              ),
            ),
          );

          expect(find.text('Sebastian Heit'), findsAtLeast(1));
          expect(find.text('@sebastian@divine.video'), findsOneWidget);
          expect(find.text('View profile'), findsOneWidget);
        });

        testWidgets('renders message input with hint', (tester) async {
          await tester.pumpWidget(
            buildSubject(
              child: ConversationView(
                recipientProfile: testProfile,
                isGroup: false,
                participantCount: 1,
                participantNames: const [],
                userPubkey: '',
              ),
            ),
          );

          expect(find.text('Say something...'), findsOneWidget);
        });

        testWidgets('hides send button when input is empty', (tester) async {
          await tester.pumpWidget(
            buildSubject(
              child: ConversationView(
                recipientProfile: testProfile,
                isGroup: false,
                participantCount: 1,
                participantNames: const [],
                userPubkey: '',
              ),
            ),
          );

          expect(find.byIcon(Icons.arrow_upward), findsNothing);
        });

        testWidgets('shows send button when text is entered', (
          tester,
        ) async {
          await tester.pumpWidget(
            buildSubject(
              child: ConversationView(
                recipientProfile: testProfile,
                isGroup: false,
                participantCount: 1,
                participantNames: const [],
                userPubkey: '',
              ),
            ),
          );

          await tester.enterText(find.byType(TextField), 'Hello');
          await tester.pump();

          expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
        });

        testWidgets('renders back button with semantic label', (
          tester,
        ) async {
          await tester.pumpWidget(
            buildSubject(
              child: ConversationView(
                recipientProfile: testProfile,
                isGroup: false,
                participantCount: 1,
                participantNames: const [],
                userPubkey: '',
              ),
            ),
          );

          expect(
            find.bySemanticsLabel('Back'),
            findsOneWidget,
          );
        });

        testWidgets(
          'renders send button with semantic label when text entered',
          (
            tester,
          ) async {
            await tester.pumpWidget(
              buildSubject(
                child: ConversationView(
                  recipientProfile: testProfile,
                  isGroup: false,
                  participantCount: 1,
                  participantNames: const [],
                  userPubkey: '',
                ),
              ),
            );

            await tester.enterText(find.byType(TextField), 'Hello');
            await tester.pump();

            expect(
              find.bySemanticsLabel('Send message'),
              findsOneWidget,
            );
          },
        );

        testWidgets(
          'navigates to profile when View profile is tapped',
          (tester) async {
            final mockGoRouter = MockGoRouter();
            when(
              () => mockGoRouter.push<Object?>(
                any(),
                extra: any(named: 'extra'),
              ),
            ).thenAnswer((_) async => null);

            await tester.pumpWidget(
              MaterialApp(
                home: MockGoRouterProvider(
                  goRouter: mockGoRouter,
                  child: ConversationView(
                    recipientProfile: testProfile,
                    isGroup: false,
                    participantCount: 1,
                    participantNames: const [],
                    userPubkey: '',
                  ),
                ),
              ),
            );

            await tester.tap(find.text('View profile'));
            await tester.pump();

            final expectedNpub = NostrKeyUtils.encodePubKey(testProfile.pubkey);
            final expectedPath = OtherProfileScreen.pathForNpub(expectedNpub);

            verify(
              () => mockGoRouter.push<Object?>(
                expectedPath,
                extra: <String, String?>{
                  'displayName': testProfile.bestDisplayName,
                  'avatarUrl': testProfile.picture,
                },
              ),
            ).called(1);
          },
        );
      });
    });

    group('group mode', () {
      group('renders', () {
        testWidgets('renders group header with participant count', (
          tester,
        ) async {
          await tester.pumpWidget(
            buildSubject(
              child: const ConversationView(
                isGroup: true,
                participantCount: 5,
                participantNames: [
                  'Sebastian Heit',
                  'rabble',
                  'AC555',
                  'Improvising',
                  'dspurgin',
                ],
                userPubkey: '',
              ),
            ),
          );

          expect(find.text('5 people'), findsOneWidget);
        });

        testWidgets('renders participant names', (tester) async {
          await tester.pumpWidget(
            buildSubject(
              child: const ConversationView(
                isGroup: true,
                participantCount: 3,
                participantNames: ['Alice', 'Bob', 'Charlie'],
                userPubkey: '',
              ),
            ),
          );

          expect(find.text('Alice, Bob, Charlie'), findsOneWidget);
        });

        testWidgets('renders close button instead of back chevron', (
          tester,
        ) async {
          await tester.pumpWidget(
            buildSubject(
              child: const ConversationView(
                isGroup: true,
                participantCount: 2,
                participantNames: ['Alice', 'Bob'],
                userPubkey: '',
              ),
            ),
          );

          expect(find.byIcon(Icons.close), findsOneWidget);
          expect(find.byIcon(Icons.chevron_left), findsNothing);
        });

        testWidgets('renders close button with semantic label', (
          tester,
        ) async {
          await tester.pumpWidget(
            buildSubject(
              child: const ConversationView(
                isGroup: true,
                participantCount: 2,
                participantNames: ['Alice', 'Bob'],
                userPubkey: '',
              ),
            ),
          );

          expect(
            find.bySemanticsLabel('Close conversation'),
            findsOneWidget,
          );
        });

        testWidgets('renders message input', (tester) async {
          await tester.pumpWidget(
            buildSubject(
              child: const ConversationView(
                isGroup: true,
                participantCount: 2,
                participantNames: ['Alice', 'Bob'],
                userPubkey: '',
              ),
            ),
          );

          expect(find.text('Say something...'), findsOneWidget);
        });

        testWidgets('renders empty conversation state', (tester) async {
          await tester.pumpWidget(
            buildSubject(
              child: const ConversationView(
                isGroup: true,
                participantCount: 2,
                participantNames: ['Alice', 'Bob'],
                userPubkey: '',
              ),
            ),
          );

          // Group mode with no profile shows fallback empty state
          expect(find.text('No messages yet'), findsOneWidget);
        });
      });
    });

    group('shared video card', () {
      const userPubkey =
          'user1234567890123456789012345678901234567890123456789012345678901';
      const otherPubkey =
          'other123456789012345678901234567890123456789012345678901234567890';
      const conversationId =
          'conv1234567890123456789012345678901234567890123456789012345678901';
      const giftWrapId =
          'gift1234567890123456789012345678901234567890123456789012345678901';
      const eventId =
          'evnt1234567890123456789012345678901234567890123456789012345678901';

      late _MockConversationBloc mockBloc;

      setUp(() {
        mockBloc = _MockConversationBloc();
      });

      Widget buildWithMessages(List<DmMessage> messages) {
        whenListen(
          mockBloc,
          const Stream<ConversationState>.empty(),
          initialState: ConversationState(
            status: ConversationStatus.loaded,
            messages: messages,
          ),
        );

        return buildSubject(
          child: BlocProvider<ConversationBloc>.value(
            value: mockBloc,
            child: ConversationView(
              recipientProfile: testProfile,
              isGroup: false,
              participantCount: 1,
              participantNames: const [],
              userPubkey: userPubkey,
            ),
          ),
        );
      }

      testWidgets('renders plain text as message bubble', (tester) async {
        await tester.pumpWidget(
          buildWithMessages([
            const DmMessage(
              id: eventId,
              conversationId: conversationId,
              senderPubkey: otherPubkey,
              content: 'Hello there!',
              createdAt: 1700000000,
              giftWrapId: giftWrapId,
            ),
          ]),
        );

        expect(find.text('Hello there!'), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow), findsNothing);
      });

      testWidgets('renders shared video as card with play icon', (
        tester,
      ) async {
        const videoStableId =
            'vid12345678901234567890123456789012345678901234567890123456789012';
        const shareContent =
            '🎬 Check out this vine:\n'
            '"My Cool Video"\n'
            '\n'
            'https://divine.video/video/$videoStableId\n'
            '\n'
            'Shared via Divine';

        await tester.pumpWidget(
          buildWithMessages([
            const DmMessage(
              id: eventId,
              conversationId: conversationId,
              senderPubkey: otherPubkey,
              content: shareContent,
              createdAt: 1700000000,
              giftWrapId: giftWrapId,
            ),
          ]),
        );

        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
        expect(find.text('My Cool Video'), findsOneWidget);
      });

      testWidgets('renders personal message above video card', (
        tester,
      ) async {
        const videoStableId =
            'vid12345678901234567890123456789012345678901234567890123456789012';
        const shareContent =
            'You gotta see this!\n'
            '\n'
            '🎬 Check out this vine:\n'
            '"Amazing Vine"\n'
            '\n'
            'https://divine.video/video/$videoStableId\n'
            '\n'
            'Shared via Divine';

        await tester.pumpWidget(
          buildWithMessages([
            const DmMessage(
              id: eventId,
              conversationId: conversationId,
              senderPubkey: otherPubkey,
              content: shareContent,
              createdAt: 1700000000,
              giftWrapId: giftWrapId,
            ),
          ]),
        );

        // Personal message rendered as text bubble
        expect(find.text('You gotta see this!'), findsOneWidget);
        // Video card with play icon and title
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
        expect(find.text('Amazing Vine'), findsOneWidget);
      });

      testWidgets('renders shared video without title', (tester) async {
        const videoStableId =
            'vid12345678901234567890123456789012345678901234567890123456789012';
        const shareContent =
            '🎬 Check out this vine:\n'
            '\n'
            'https://divine.video/video/$videoStableId\n'
            '\n'
            'Shared via Divine';

        await tester.pumpWidget(
          buildWithMessages([
            const DmMessage(
              id: eventId,
              conversationId: conversationId,
              senderPubkey: otherPubkey,
              content: shareContent,
              createdAt: 1700000000,
              giftWrapId: giftWrapId,
            ),
          ]),
        );

        // Card renders with play icon but no title
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      });

      testWidgets('renders sent video card aligned right', (tester) async {
        const videoStableId =
            'vid12345678901234567890123456789012345678901234567890123456789012';
        const shareContent =
            '🎬 Check out this vine:\n'
            '"My Video"\n'
            '\n'
            'https://divine.video/video/$videoStableId\n'
            '\n'
            'Shared via Divine';

        await tester.pumpWidget(
          buildWithMessages([
            const DmMessage(
              id: eventId,
              conversationId: conversationId,
              senderPubkey: userPubkey,
              content: shareContent,
              createdAt: 1700000000,
              giftWrapId: giftWrapId,
            ),
          ]),
        );

        // Find the Column wrapping the message
        final column = tester.widget<Column>(
          find
              .ancestor(
                of: find.byIcon(Icons.play_arrow),
                matching: find.byType(Column),
              )
              .first,
        );
        expect(column.crossAxisAlignment, CrossAxisAlignment.end);
      });

      testWidgets('renders card with semantics for shared video', (
        tester,
      ) async {
        const videoStableId =
            'vid12345678901234567890123456789012345678901234567890123456789012';
        const shareContent =
            '🎬 Check out this vine:\n'
            '"Great Vine"\n'
            '\n'
            'https://divine.video/video/$videoStableId\n'
            '\n'
            'Shared via Divine';

        await tester.pumpWidget(
          buildWithMessages([
            const DmMessage(
              id: eventId,
              conversationId: conversationId,
              senderPubkey: otherPubkey,
              content: shareContent,
              createdAt: 1700000000,
              giftWrapId: giftWrapId,
            ),
          ]),
        );

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.label == 'Shared video: Great Vine',
          ),
        );
        expect(semantics.properties.button, isTrue);
      });
    });

    group('message grouping', () {
      const userPubkey =
          'user1234567890123456789012345678901234567890123456789012345678901';
      const otherPubkey =
          'other123456789012345678901234567890123456789012345678901234567890';
      const conversationId =
          'conv1234567890123456789012345678901234567890123456789012345678901';
      const giftWrapId =
          'gift1234567890123456789012345678901234567890123456789012345678901';

      late _MockConversationBloc mockBloc;

      setUp(() {
        mockBloc = _MockConversationBloc();
      });

      Widget buildWithMessages(List<DmMessage> messages) {
        whenListen(
          mockBloc,
          const Stream<ConversationState>.empty(),
          initialState: ConversationState(
            status: ConversationStatus.loaded,
            messages: messages,
          ),
        );

        return buildSubject(
          child: BlocProvider<ConversationBloc>.value(
            value: mockBloc,
            child: ConversationView(
              recipientProfile: testProfile,
              isGroup: false,
              participantCount: 1,
              participantNames: const [],
              userPubkey: userPubkey,
            ),
          ),
        );
      }

      testWidgets(
        'renders timestamp only on last message in group',
        (tester) async {
          // Two consecutive messages from the same sender
          await tester.pumpWidget(
            buildWithMessages([
              const DmMessage(
                id: 'msg21234567890123456789012345678901234567890123456789012345678901',
                conversationId: conversationId,
                senderPubkey: otherPubkey,
                content: 'Second message',
                createdAt: 1700000060,
                giftWrapId:
                    'gift2234567890123456789012345678901234567890123456789012345678901',
              ),
              const DmMessage(
                id: 'msg11234567890123456789012345678901234567890123456789012345678901',
                conversationId: conversationId,
                senderPubkey: otherPubkey,
                content: 'First message',
                createdAt: 1700000000,
                giftWrapId: giftWrapId,
              ),
            ]),
          );

          expect(find.text('First message'), findsOneWidget);
          expect(find.text('Second message'), findsOneWidget);

          // Only one timestamp label should render (for the last in group)
          final timestampFinder = find.textContaining('ago');
          expect(timestampFinder, findsOneWidget);
        },
      );

      testWidgets('renders emoji-only message with large font', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWithMessages([
            const DmMessage(
              id: 'emoji234567890123456789012345678901234567890123456789012345678901',
              conversationId: conversationId,
              senderPubkey: otherPubkey,
              content: '😀🎉',
              createdAt: 1700000000,
              giftWrapId: giftWrapId,
            ),
          ]),
        );

        // Emoji-only messages render without bubble background
        final emojiText = tester.widget<Text>(find.text('😀🎉'));
        expect(emojiText.style!.fontSize, greaterThan(20));
      });

      testWidgets('renders Today divider for messages from today', (
        tester,
      ) async {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await tester.pumpWidget(
          buildWithMessages([
            DmMessage(
              id: 'today234567890123456789012345678901234567890123456789012345678901',
              conversationId: conversationId,
              senderPubkey: otherPubkey,
              content: 'Hello today',
              createdAt: now,
              giftWrapId: giftWrapId,
            ),
          ]),
        );

        expect(find.text('Today'), findsOneWidget);
      });
    });

    group('bubble colors', () {
      const userPubkey =
          'user1234567890123456789012345678901234567890123456789012345678901';
      const otherPubkey =
          'other123456789012345678901234567890123456789012345678901234567890';
      const conversationId =
          'conv1234567890123456789012345678901234567890123456789012345678901';
      const giftWrapId =
          'gift1234567890123456789012345678901234567890123456789012345678901';
      const eventId =
          'evnt1234567890123456789012345678901234567890123456789012345678901';

      late _MockConversationBloc mockBloc;

      setUp(() {
        mockBloc = _MockConversationBloc();
      });

      Widget buildWithMessages(List<DmMessage> messages) {
        whenListen(
          mockBloc,
          const Stream<ConversationState>.empty(),
          initialState: ConversationState(
            status: ConversationStatus.loaded,
            messages: messages,
          ),
        );

        return buildSubject(
          child: BlocProvider<ConversationBloc>.value(
            value: mockBloc,
            child: ConversationView(
              recipientProfile: testProfile,
              isGroup: false,
              participantCount: 1,
              participantNames: const [],
              userPubkey: userPubkey,
            ),
          ),
        );
      }

      testWidgets(
        'sent message bubble uses ${VineTheme.primaryAccessible}',
        (tester) async {
          await tester.pumpWidget(
            buildWithMessages([
              const DmMessage(
                id: eventId,
                conversationId: conversationId,
                senderPubkey: userPubkey,
                content: 'Hello from me',
                createdAt: 1700000000,
                giftWrapId: giftWrapId,
              ),
            ]),
          );

          final container = tester.widget<Container>(
            find
                .ancestor(
                  of: find.text('Hello from me'),
                  matching: find.byType(Container),
                )
                .first,
          );
          final decoration = container.decoration! as BoxDecoration;

          expect(
            decoration.color,
            equals(VineTheme.primaryAccessible),
            reason:
                'Sent message bubble should use VineTheme.primaryAccessible '
                '(#00A572)',
          );
        },
      );

      testWidgets(
        'received message bubble uses ${VineTheme.containerLow}',
        (tester) async {
          await tester.pumpWidget(
            buildWithMessages([
              const DmMessage(
                id: eventId,
                conversationId: conversationId,
                senderPubkey: otherPubkey,
                content: 'Hello from them',
                createdAt: 1700000000,
                giftWrapId: giftWrapId,
              ),
            ]),
          );

          final container = tester.widget<Container>(
            find
                .ancestor(
                  of: find.text('Hello from them'),
                  matching: find.byType(Container),
                )
                .first,
          );
          final decoration = container.decoration! as BoxDecoration;

          expect(
            decoration.color,
            equals(VineTheme.containerLow),
            reason:
                'Received message bubble should use VineTheme.containerLow '
                '(#0E2B21)',
          );
        },
      );
    });

    group('Kind 15 file messages', () {
      const userPubkey =
          'user1234567890123456789012345678901234567890123456789012345678901';
      const otherPubkey =
          'other123456789012345678901234567890123456789012345678901234567890';
      const conversationId =
          'conv1234567890123456789012345678901234567890123456789012345678901';
      const giftWrapId =
          'gift1234567890123456789012345678901234567890123456789012345678901';
      const eventId =
          'file1234567890123456789012345678901234567890123456789012345678901';

      late _MockConversationBloc mockBloc;

      setUp(() {
        mockBloc = _MockConversationBloc();
      });

      Widget buildWithMessages(List<DmMessage> messages) {
        whenListen(
          mockBloc,
          const Stream<ConversationState>.empty(),
          initialState: ConversationState(
            status: ConversationStatus.loaded,
            messages: messages,
          ),
        );

        return buildSubject(
          child: BlocProvider<ConversationBloc>.value(
            value: mockBloc,
            child: ConversationView(
              recipientProfile: testProfile,
              isGroup: false,
              participantCount: 1,
              participantNames: const [],
              userPubkey: userPubkey,
            ),
          ),
        );
      }

      testWidgets(
        'renders Kind 15 file message URL as text bubble',
        (tester) async {
          const fileUrl = 'https://files.example.com/encrypted/abc123.enc';

          await tester.pumpWidget(
            buildWithMessages([
              const DmMessage(
                id: eventId,
                conversationId: conversationId,
                senderPubkey: otherPubkey,
                content: fileUrl,
                createdAt: 1700000000,
                giftWrapId: giftWrapId,
                messageKind: 15,
                fileMetadata: DmFileMetadata(
                  fileType: 'image/jpeg',
                  encryptionAlgorithm: 'aes-gcm',
                  decryptionKey: 'aabb112233445566aabb112233445566',
                  decryptionNonce: 'ccdd112233445566',
                  fileHash:
                      'deadbeef12345678deadbeef12345678deadbeef12345678deadbeef12345678',
                ),
              ),
            ]),
          );

          // Kind 15 file messages currently fall through to text bubble
          // rendering because _BlocMessagesList checks shared video
          // format, not messageKind. The URL content appears as text.
          expect(find.text(fileUrl), findsOneWidget);

          // Should not render as a shared video card (no play icon)
          expect(find.byIcon(Icons.play_arrow), findsNothing);
        },
      );

      testWidgets(
        'renders Kind 15 file message with image fileType as text bubble',
        (tester) async {
          const fileUrl = 'https://files.example.com/encrypted/photo.enc';

          await tester.pumpWidget(
            buildWithMessages([
              const DmMessage(
                id: eventId,
                conversationId: conversationId,
                senderPubkey: otherPubkey,
                content: fileUrl,
                createdAt: 1700000000,
                giftWrapId: giftWrapId,
                messageKind: 15,
                fileMetadata: DmFileMetadata(
                  fileType: 'image/png',
                  encryptionAlgorithm: 'aes-gcm',
                  decryptionKey: 'aabb112233445566aabb112233445566',
                  decryptionNonce: 'ccdd112233445566',
                  fileHash:
                      'deadbeef12345678deadbeef12345678deadbeef12345678deadbeef12345678',
                  dimensions: '1920x1080',
                ),
              ),
            ]),
          );

          // Image file messages also render as text since there is no
          // specialized Kind 15 UI yet. The file URL is shown as text.
          expect(find.text(fileUrl), findsOneWidget);
        },
      );

      testWidgets(
        'renders sent Kind 15 file message with correct bubble color',
        (tester) async {
          const fileUrl = 'https://files.example.com/encrypted/sent.enc';

          await tester.pumpWidget(
            buildWithMessages([
              const DmMessage(
                id: eventId,
                conversationId: conversationId,
                senderPubkey: userPubkey,
                content: fileUrl,
                createdAt: 1700000000,
                giftWrapId: giftWrapId,
                messageKind: 15,
                fileMetadata: DmFileMetadata(
                  fileType: 'image/jpeg',
                  encryptionAlgorithm: 'aes-gcm',
                  decryptionKey: 'aabb112233445566aabb112233445566',
                  decryptionNonce: 'ccdd112233445566',
                  fileHash:
                      'deadbeef12345678deadbeef12345678deadbeef12345678deadbeef12345678',
                ),
              ),
            ]),
          );

          final container = tester.widget<Container>(
            find
                .ancestor(
                  of: find.text(fileUrl),
                  matching: find.byType(Container),
                )
                .first,
          );
          final decoration = container.decoration! as BoxDecoration;

          expect(
            decoration.color,
            equals(VineTheme.primaryAccessible),
            reason:
                'Sent Kind 15 file message bubble should use '
                'VineTheme.primaryAccessible',
          );
        },
      );

      testWidgets(
        'renders received Kind 15 file message aligned left',
        (tester) async {
          const fileUrl = 'https://files.example.com/encrypted/recv.enc';

          await tester.pumpWidget(
            buildWithMessages([
              const DmMessage(
                id: eventId,
                conversationId: conversationId,
                senderPubkey: otherPubkey,
                content: fileUrl,
                createdAt: 1700000000,
                giftWrapId: giftWrapId,
                messageKind: 15,
                fileMetadata: DmFileMetadata(
                  fileType: 'video/mp4',
                  encryptionAlgorithm: 'aes-gcm',
                  decryptionKey: 'aabb112233445566aabb112233445566',
                  decryptionNonce: 'ccdd112233445566',
                  fileHash:
                      'deadbeef12345678deadbeef12345678deadbeef12345678deadbeef12345678',
                ),
              ),
            ]),
          );

          // Find the Column wrapping the message; received messages align
          // to CrossAxisAlignment.start (left).
          final column = tester.widget<Column>(
            find
                .ancestor(
                  of: find.text(fileUrl),
                  matching: find.byType(Column),
                )
                .first,
          );
          expect(column.crossAxisAlignment, CrossAxisAlignment.start);
        },
      );
    });

    group('more options actions', () {
      late _MockContentBlocklistService mockBlocklistService;

      setUp(() {
        mockBlocklistService = _MockContentBlocklistService();
      });

      Widget buildWithProviders({required Widget child}) {
        return ProviderScope(
          overrides: [
            contentBlocklistServiceProvider.overrideWithValue(
              mockBlocklistService,
            ),
          ],
          child: MaterialApp(home: child),
        );
      }

      testWidgets('tapping Block user shows confirmation dialog', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWithProviders(
            child: ConversationView(
              recipientProfile: testProfile,
              isGroup: false,
              participantCount: 1,
              participantNames: const [],
              userPubkey:
                  'ourpubkey123456789012345678901234567890123456789012345678901234',
            ),
          ),
        );

        // Open more options sheet
        await tester.tap(find.byIcon(Icons.more_horiz));
        await tester.pumpAndSettle();

        // Tap "Block user"
        await tester.tap(find.text('Block user'));
        await tester.pumpAndSettle();

        // Confirm the block dialog appeared
        expect(
          find.text(
            'Are you sure you want to block Sebastian Heit? '
            'You will no longer receive messages from this user.',
          ),
          findsOneWidget,
        );
        expect(find.text('Block'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      });

      testWidgets('confirming block calls blockUser on service', (
        tester,
      ) async {
        const ourPubkey =
            'ourpubkey123456789012345678901234567890123456789012345678901234';

        await tester.pumpWidget(
          buildWithProviders(
            child: ConversationView(
              recipientProfile: testProfile,
              isGroup: false,
              participantCount: 1,
              participantNames: const [],
              userPubkey: ourPubkey,
            ),
          ),
        );

        // Open more options → Block user → Confirm
        await tester.tap(find.byIcon(Icons.more_horiz));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Block user'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Block'));
        await tester.pumpAndSettle();

        verify(
          () => mockBlocklistService.blockUser(
            testProfile.pubkey,
            ourPubkey: ourPubkey,
          ),
        ).called(1);
      });

      testWidgets('cancelling block does not call blockUser', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWithProviders(
            child: ConversationView(
              recipientProfile: testProfile,
              isGroup: false,
              participantCount: 1,
              participantNames: const [],
              userPubkey:
                  'ourpubkey123456789012345678901234567890123456789012345678901234',
            ),
          ),
        );

        // Open more options → Block user → Cancel
        await tester.tap(find.byIcon(Icons.more_horiz));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Block user'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        verifyNever(
          () => mockBlocklistService.blockUser(
            any(),
            ourPubkey: any(named: 'ourPubkey'),
          ),
        );
      });

      testWidgets('tapping Report shows report user dialog', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWithProviders(
            child: ConversationView(
              recipientProfile: testProfile,
              isGroup: false,
              participantCount: 1,
              participantNames: const [],
              userPubkey:
                  'ourpubkey123456789012345678901234567890123456789012345678901234',
            ),
          ),
        );

        // Open more options sheet
        await tester.tap(find.byIcon(Icons.more_horiz));
        await tester.pumpAndSettle();

        // Tap "Report"
        await tester.tap(find.text('Report'));
        await tester.pumpAndSettle();

        // Verify report dialog appeared
        expect(find.text('Report User'), findsOneWidget);
        expect(
          find.text('Why are you reporting this user?'),
          findsOneWidget,
        );
        expect(find.text('Block this user'), findsOneWidget);
      });

      testWidgets(
        'more options does not open sheet for group conversations',
        (tester) async {
          await tester.pumpWidget(
            buildWithProviders(
              child: const ConversationView(
                isGroup: true,
                participantCount: 3,
                participantNames: ['Alice', 'Bob', 'Charlie'],
                userPubkey:
                    'ourpubkey123456789012345678901234567890123456789012345678901234',
              ),
            ),
          );

          // Group mode renders more_horiz but tapping it returns early
          // because recipientProfile is null
          await tester.tap(find.byIcon(Icons.more_horiz));
          await tester.pumpAndSettle();

          // No bottom sheet content should appear
          expect(find.text('Block user'), findsNothing);
          expect(find.text('Report'), findsNothing);
        },
      );
    });
  });
}
