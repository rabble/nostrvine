// ABOUTME: Widget tests for ProfileAvatarSection in the profile-setup form.
// ABOUTME: Covers avatar rendering, the upload progress indicator, and the
// ABOUTME: pick → crop → dispatch path via the imageCropLauncherProvider seam.

import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/image_crop_launcher_provider.dart';
import 'package:openvine/screens/image_crop_editor/image_crop_editor.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_avatar_section.dart';
import 'package:openvine/widgets/user_avatar.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockProfileEditorBloc
    extends MockBloc<ProfileEditorEvent, ProfileEditorState>
    implements ProfileEditorBloc {}

/// Fake crop launcher that records its invocation and returns a canned result
/// without pumping the real editor (which needs a decodable image).
class _FakeCropLauncher {
  _FakeCropLauncher(this.result);

  final Uint8List? result;
  int callCount = 0;
  ImageCropKind? lastKind;

  Future<Uint8List?> launch(
    BuildContext context, {
    required ImageCropKind kind,
    File? file,
    Uint8List? bytes,
  }) async {
    callCount++;
    lastKind = kind;
    return result;
  }
}

void main() {
  group(ProfileAvatarSection, () {
    const testPubkeyHex =
        'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';

    late MockAuthService mockAuthService;
    late _MockProfileEditorBloc bloc;
    late TextEditingController nameController;

    setUp(() {
      mockAuthService = createMockAuthService();
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkeyHex);
      bloc = _MockProfileEditorBloc();
      when(() => bloc.state).thenReturn(const ProfileEditorState());
      nameController = TextEditingController();
    });

    tearDown(() => nameController.dispose());

    Future<void> pump(
      WidgetTester tester, {
      TextEditingController? controller,
      ImageCropLauncher? cropLauncher,
    }) {
      return tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
            if (cropLauncher != null)
              imageCropLauncherProvider.overrideWithValue(cropLauncher),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: Scaffold(
              body: BlocProvider<ProfileEditorBloc>.value(
                value: bloc,
                child: ProfileAvatarSection(
                  nameController: controller ?? nameController,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the avatar preview', (tester) async {
      await pump(tester);
      expect(find.byType(UserAvatar), findsOneWidget);
    });

    testWidgets('shows a progress indicator while an avatar is uploading', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const ProfileEditorState(
          pendingAvatarStatus: PendingAvatarStatus.uploading,
        ),
      );
      await pump(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      're-subscribes the avatar name when nameController is swapped',
      (
        tester,
      ) async {
        await pump(tester);

        final swapped = TextEditingController(text: 'Bob');
        addTearDown(swapped.dispose);
        await pump(tester, controller: swapped);
        expect(tester.widget<UserAvatar>(find.byType(UserAvatar)).name, 'Bob');

        // Mutating the new controller updates the avatar only if the listener
        // was re-bound in didUpdateWidget.
        swapped.text = 'Carol';
        await tester.pump();
        expect(
          tester.widget<UserAvatar>(find.byType(UserAvatar)).name,
          'Carol',
        );
      },
    );

    group('pick → crop → dispatch', () {
      // Gallery picks route through file_selector on desktop and image_picker
      // on mobile; force a mobile platform so the mocked image_picker channel
      // is exercised. With camera present the source-button order is
      // [camera, gallery, link], so gallery is the second button.
      Finder galleryButton() => find
          .descendant(
            of: find.byType(ProfileAvatarSection),
            matching: find.byType(GestureDetector),
          )
          .at(1);

      testWidgets(
        'dispatches ProfilePictureUploadRequested with the cropped bytes',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          try {
            final croppedBytes = Uint8List.fromList([1, 2, 3, 4]);
            final launcher = _FakeCropLauncher(croppedBytes);
            await pump(tester, cropLauncher: launcher.launch);

            await tester.tap(galleryButton());
            await tester.pumpAndSettle();

            expect(launcher.callCount, 1);
            expect(launcher.lastKind, ImageCropKind.avatar);

            final captured = verify(() => bloc.add(captureAny())).captured;
            expect(captured, hasLength(1));
            final event = captured.single;
            expect(event, isA<ProfilePictureUploadRequested>());
            final upload = event as ProfilePictureUploadRequested;
            expect(upload.pubkey, testPubkeyHex);
            expect(upload.bytes, equals(croppedBytes));
            expect(upload.filename, ImageCropKind.avatar.filename);
            expect(upload.mimeType, ImageCropKind.avatar.mimeType);
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        },
      );

      testWidgets('does not dispatch when the crop is cancelled', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          final launcher = _FakeCropLauncher(null);
          await pump(tester, cropLauncher: launcher.launch);

          await tester.tap(galleryButton());
          await tester.pumpAndSettle();

          expect(launcher.callCount, 1);
          verifyNever(() => bloc.add(any()));
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('skips crop and dispatch when no public key is available', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);
          final launcher = _FakeCropLauncher(Uint8List.fromList([1, 2, 3]));
          await pump(tester, cropLauncher: launcher.launch);

          await tester.tap(galleryButton());
          await tester.pumpAndSettle();

          expect(launcher.callCount, 0);
          verifyNever(() => bloc.add(any()));
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    });
  });
}
