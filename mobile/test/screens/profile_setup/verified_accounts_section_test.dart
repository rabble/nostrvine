// ABOUTME: Widget tests for VerifiedAccountsSection in the profile-setup form.
// ABOUTME: Covers title rendering and the "Get verified" dispatch.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/profile_setup/widgets/verified_accounts_section.dart';

class _MockProfileEditorBloc
    extends MockBloc<ProfileEditorEvent, ProfileEditorState>
    implements ProfileEditorBloc {}

class _MockMyProfileBloc extends MockBloc<MyProfileEvent, MyProfileState>
    implements MyProfileBloc {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(VerifiedAccountsSection, () {
    late _MockProfileEditorBloc editorBloc;
    late _MockMyProfileBloc myProfileBloc;

    setUp(() {
      editorBloc = _MockProfileEditorBloc();
      when(() => editorBloc.state).thenReturn(const ProfileEditorState());
      myProfileBloc = _MockMyProfileBloc();
      when(() => myProfileBloc.state).thenReturn(const MyProfileInitial());
    });

    Future<void> pump(WidgetTester tester) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<ProfileEditorBloc>.value(value: editorBloc),
                BlocProvider<MyProfileBloc>.value(value: myProfileBloc),
              ],
              child: const VerifiedAccountsSection(),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the section title and get-verified CTA', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text(l10n.profileEditVerifiedAccountsTitle), findsOneWidget);
      expect(find.text(l10n.profileEditGetVerifiedCta), findsOneWidget);
    });

    testWidgets('tapping get-verified dispatches VerifierLaunchRequested', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text(l10n.profileEditGetVerifiedCta));
      verify(
        () => editorBloc.add(const VerifierLaunchRequested()),
      ).called(1);
    });
  });
}
