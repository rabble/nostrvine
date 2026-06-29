// ABOUTME: Widget tests for UsernameField in the profile-setup form.
// ABOUTME: Covers label/status rendering, external-mode disabling, and dispatch.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/profile_setup/widgets/username_field.dart';
import 'package:openvine/widgets/profile_editor/username_status_indicator.dart';

class _MockProfileEditorBloc
    extends MockBloc<ProfileEditorEvent, ProfileEditorState>
    implements ProfileEditorBloc {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(UsernameField, () {
    late TextEditingController controller;
    late _MockProfileEditorBloc bloc;

    setUp(() {
      controller = TextEditingController();
      bloc = _MockProfileEditorBloc();
      when(() => bloc.state).thenReturn(const ProfileEditorState());
    });

    tearDown(() => controller.dispose());

    Future<void> pump(WidgetTester tester) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: BlocProvider<ProfileEditorBloc>.value(
              value: bloc,
              child: UsernameField(controller: controller),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the localized label and the status indicator', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text(l10n.profileSetupUsernameLabel), findsOneWidget);
      expect(find.byType(UsernameStatusIndicator), findsOneWidget);
    });

    testWidgets('typing dispatches UsernameChanged with the entered value', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byType(TextFormField), 'bob');
      final changes = verify(
        () => bloc.add(captureAny()),
      ).captured.whereType<UsernameChanged>().toList();
      expect(changes.last.username, 'bob');
    });

    testWidgets('field is disabled in external NIP-05 mode', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(const ProfileEditorState(nip05Mode: Nip05Mode.external_));
      await pump(tester);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
      // The status indicator is hidden while editing an external identifier.
      expect(find.byType(UsernameStatusIndicator), findsNothing);
    });
  });
}
