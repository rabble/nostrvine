// ABOUTME: Tests for DraftsTab widget
// ABOUTME: Verifies drafts list, loading, error, and empty states

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/drafts_library/drafts_library_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/widgets/library/drafts_tab.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';

class _MockDraftsLibraryBloc
    extends MockBloc<DraftsLibraryEvent, DraftsLibraryState>
    implements DraftsLibraryBloc {}

void main() {
  group(DraftsTab, () {
    late _MockDraftsLibraryBloc mockBloc;

    DivineVideoDraft createDraft({
      String? id,
      String title = 'Test Draft',
    }) {
      return DivineVideoDraft(
        id: id ?? 'draft-${DateTime.now().millisecondsSinceEpoch}',
        clips: const [],
        title: title,
        description: 'Test Description',
        hashtags: const {},
        selectedApproach: 'default',
        createdAt: DateTime(2026),
        lastModified: DateTime(2026),
        publishStatus: PublishStatus.draft,
        publishAttempts: 0,
      );
    }

    setUp(() {
      mockBloc = _MockDraftsLibraryBloc();
    });

    Widget buildWidget() {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: BlocProvider<DraftsLibraryBloc>.value(
              value: mockBloc,
              child: const DraftsTab(),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('loading indicator when initial state', (tester) async {
        when(() => mockBloc.state).thenReturn(const DraftsLibraryInitial());

        await tester.pumpWidget(buildWidget());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('loading indicator when loading state', (tester) async {
        when(() => mockBloc.state).thenReturn(const DraftsLibraryLoading());

        await tester.pumpWidget(buildWidget());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('error message when error state', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const DraftsLibraryError(message: 'Failed to load drafts'),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.text('Failed to load drafts'), findsOneWidget);
      });

      testWidgets('$EmptyLibraryState when no drafts', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const DraftsLibraryLoaded(drafts: []),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.byType(EmptyLibraryState), findsOneWidget);
        expect(find.text('No Drafts Yet'), findsOneWidget);
      });

      testWidgets('drafts list when drafts are loaded', (tester) async {
        when(() => mockBloc.state).thenReturn(
          DraftsLibraryLoaded(
            drafts: [
              createDraft(id: 'draft1', title: 'Draft 1'),
              createDraft(id: 'draft2', title: 'Draft 2'),
            ],
          ),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(DraftListTile), findsNWidgets(2));
      });
    });
  });

  group(DraftListTile, () {
    DivineVideoDraft createDraft({
      String? id,
      String title = 'Test Draft',
      DateTime? lastModified,
    }) {
      return DivineVideoDraft(
        id: id ?? 'draft-${DateTime.now().millisecondsSinceEpoch}',
        clips: const [],
        title: title,
        description: 'Test Description',
        hashtags: const {},
        selectedApproach: 'default',
        createdAt: DateTime(2026),
        lastModified: lastModified ?? DateTime(2026),
        publishStatus: PublishStatus.draft,
        publishAttempts: 0,
      );
    }

    Widget buildWidget({
      required DivineVideoDraft draft,
      VoidCallback? onTap,
      VoidCallback? onOpenMore,
      bool enableShrink = false,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: DraftListTile(
            draft: draft,
            onTap: onTap,
            onOpenMore: onOpenMore,
            enableShrink: enableShrink,
          ),
        ),
      );
    }

    testWidgets('renders draft title', (tester) async {
      await tester.pumpWidget(
        buildWidget(draft: createDraft(title: 'My Video Draft')),
      );

      expect(find.text('My Video Draft'), findsOneWidget);
    });

    testWidgets('shows untitled when title is empty', (tester) async {
      await tester.pumpWidget(
        buildWidget(draft: createDraft(title: '')),
      );

      expect(find.text('Untitled'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildWidget(
          draft: createDraft(),
          onTap: () => tapped = true,
        ),
      );

      await tester.tap(find.byType(InkWell).first);
      expect(tapped, isTrue);
    });

    testWidgets('shows more button when onOpenMore is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          draft: createDraft(),
          onOpenMore: () {},
        ),
      );

      // Finds the trailing IconButton (more options button)
      expect(find.byType(IconButton), findsOneWidget);
    });
  });
}
