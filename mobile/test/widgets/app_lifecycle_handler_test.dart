// ABOUTME: Regression tests for app-level lifecycle autosave handling
// ABOUTME: Verifies pending editor autosaves flush before background kills

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/app_lifecycle_handler.dart';

class _MockAuthService extends Mock implements AuthService {}

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
  testWidgets('flushes pending autosave before background lifecycle states', (
    tester,
  ) async {
    final authService = _MockAuthService();
    final authStateController = StreamController<AuthState>();
    when(() => authService.isAuthenticated).thenReturn(false);
    when(
      () => authService.authStateStream,
    ).thenAnswer((_) => authStateController.stream);

    final editorNotifier = _FlushTrackingVideoEditorNotifier();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          videoEditorProvider.overrideWith(() => editorNotifier),
        ],
        child: const MaterialApp(
          home: AppLifecycleHandler(child: SizedBox.shrink()),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);

    expect(editorNotifier.flushCalls, 3);
    await tester.pump(const Duration(seconds: 31));
  });
}
