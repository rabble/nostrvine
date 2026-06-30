// ABOUTME: Widget tests for BannerEditingBlock in the profile-setup form.
// ABOUTME: Covers the pick → crop → dispatch path via imageCropLauncherProvider.

import 'dart:io';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/image_crop_launcher_provider.dart';
import 'package:openvine/screens/image_crop_editor/image_crop_editor.dart';
import 'package:openvine/screens/profile_setup/widgets/banner_editing_block.dart';

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
  group(BannerEditingBlock, () {
    const testPubkeyHex =
        'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';

    late MockAuthService mockAuthService;
    late _MockProfileEditorBloc bloc;

    setUp(() {
      mockAuthService = createMockAuthService();
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkeyHex);
      bloc = _MockProfileEditorBloc();
      when(() => bloc.state).thenReturn(const ProfileEditorState());
    });

    Future<void> pump(
      WidgetTester tester, {
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
                child: const BannerEditingBlock(),
              ),
            ),
          ),
        ),
      );
    }

    Finder uploadButton() => find.widgetWithText(
      OutlinedButton,
      lookupAppLocalizations(
        const Locale('en'),
      ).profileSetupBannerUploadButton,
    );

    testWidgets(
      'dispatches ProfileBannerUploadRequested with the cropped bytes',
      (tester) async {
        final croppedBytes = Uint8List.fromList([1, 2, 3, 4]);
        final launcher = _FakeCropLauncher(croppedBytes);
        await pump(tester, cropLauncher: launcher.launch);

        await tester.tap(uploadButton());
        await tester.pumpAndSettle();

        expect(launcher.callCount, 1);
        expect(launcher.lastKind, ImageCropKind.banner);

        final captured = verify(() => bloc.add(captureAny())).captured;
        expect(captured, hasLength(1));
        final event = captured.single;
        expect(event, isA<ProfileBannerUploadRequested>());
        final upload = event as ProfileBannerUploadRequested;
        expect(upload.pubkey, testPubkeyHex);
        expect(upload.bytes, equals(croppedBytes));
        expect(upload.filename, ImageCropKind.banner.filename);
        expect(upload.mimeType, ImageCropKind.banner.mimeType);
      },
    );

    testWidgets('does not dispatch when the crop is cancelled', (tester) async {
      final launcher = _FakeCropLauncher(null);
      await pump(tester, cropLauncher: launcher.launch);

      await tester.tap(uploadButton());
      await tester.pumpAndSettle();

      expect(launcher.callCount, 1);
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('skips crop and dispatch when no public key is available', (
      tester,
    ) async {
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);
      final launcher = _FakeCropLauncher(Uint8List.fromList([1, 2, 3]));
      await pump(tester, cropLauncher: launcher.launch);

      await tester.tap(uploadButton());
      await tester.pumpAndSettle();

      expect(launcher.callCount, 0);
      verifyNever(() => bloc.add(any()));
    });
  });
}
