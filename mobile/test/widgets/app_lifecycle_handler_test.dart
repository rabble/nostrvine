// ABOUTME: Regression tests for app-level lifecycle autosave handling
// ABOUTME: Verifies pending editor autosaves flush before background kills

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/widgets/app_lifecycle_handler.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

class _NoopVideoPublishNotifier extends VideoPublishNotifier {
  @override
  VideoPublishProviderState build() => const VideoPublishProviderState();

  @override
  Future<void> resumePendingPublishes(BuildContext context) async {}
}

class _FlushTrackingVideoEditorNotifier extends VideoEditorNotifier {
  int flushCalls = 0;

  @override
  VideoEditorProviderState build() => VideoEditorProviderState();

  @override
  Future<bool> flushPendingAutosave() async {
    flushCalls++;
    return true;
  }
}

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('flushes pending autosave before background lifecycle states', (
    tester,
  ) async {
    final authService = _MockAuthService();
    addTearDown(() {
      BackgroundActivityManager().onAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
    });

    when(() => authService.isAuthenticated).thenReturn(true);
    when(
      () => authService.authStateStream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());
    final clipLibraryService = _MockClipLibraryService();
    when(clipLibraryService.migrateOldClips).thenAnswer((_) async {});
    when(clipLibraryService.purgeExpiredTrash).thenAnswer((_) async => 0);
    final draftStorageService = _MockDraftStorageService();
    when(draftStorageService.migrateOldDrafts).thenAnswer((_) async {});

    final editorNotifier = _FlushTrackingVideoEditorNotifier();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          videoEditorProvider.overrideWith(() => editorNotifier),
          videoPublishProvider.overrideWith(_NoopVideoPublishNotifier.new),
          clipLibraryServiceProvider.overrideWithValue(clipLibraryService),
          draftStorageServiceProvider.overrideWithValue(draftStorageService),
        ],
        child: const MaterialApp(
          home: AppLifecycleHandler(child: SizedBox.shrink()),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);

    // Do not simulate detached here: flutter_tester treats it as shell teardown.
    expect(editorNotifier.flushCalls, 3);
    // Drain BackgroundActivityManager's private 30-second suspension timer.
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('treats inactive as non-foreground on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final authService = _MockAuthService();
    addTearDown(() {
      BackgroundActivityManager().onAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
    });

    when(() => authService.isAuthenticated).thenReturn(true);
    when(
      () => authService.authStateStream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());
    final clipLibraryService = _MockClipLibraryService();
    when(clipLibraryService.migrateOldClips).thenAnswer((_) async {});
    when(clipLibraryService.purgeExpiredTrash).thenAnswer((_) async => 0);
    final draftStorageService = _MockDraftStorageService();
    when(draftStorageService.migrateOldDrafts).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          videoPublishProvider.overrideWith(_NoopVideoPublishNotifier.new),
          clipLibraryServiceProvider.overrideWithValue(clipLibraryService),
          draftStorageServiceProvider.overrideWithValue(draftStorageService),
        ],
        child: const MaterialApp(
          home: AppLifecycleHandler(child: SizedBox.shrink()),
        ),
      ),
    );

    final context = tester.element(find.byType(AppLifecycleHandler));
    final container = ProviderScope.containerOf(context);
    expect(container.read(appForegroundProvider), isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(container.read(appForegroundProvider), isFalse);
    await tester.pump(const Duration(seconds: 31));
    debugDefaultTargetPlatformOverride = null;
  });
}
