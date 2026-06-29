// ABOUTME: Widget tests for ProfileAvatarSection in the profile-setup form.
// ABOUTME: Covers avatar rendering and the upload progress indicator.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_avatar_section.dart';
import 'package:openvine/widgets/user_avatar.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockProfileEditorBloc
    extends MockBloc<ProfileEditorEvent, ProfileEditorState>
    implements ProfileEditorBloc {}

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
    }) {
      return tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
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
  });
}
