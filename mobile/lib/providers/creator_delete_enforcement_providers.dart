// ABOUTME: Riverpod wiring for creator-delete media cleanup enforcement.
// ABOUTME: Scopes the NIP-98 repository and its HTTP client together.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/repositories/creator_delete_enforcement_repository.dart';
import 'package:openvine/services/crash_reporting_service.dart';

final creatorDeleteEnforcementRepositoryProvider =
    Provider<CreatorDeleteEnforcementRepository>((ref) {
      final client = ref.watch(instrumentedHttpClientFactoryProvider)();
      ref.onDispose(client.close);
      return CreatorDeleteEnforcementRepository(
        baseUrl: ref.watch(currentEnvironmentProvider).moderationApiBaseUrl,
        httpClient: client,
        nip98AuthService: ref.watch(nip98AuthServiceProvider),
        reportError: (error, stackTrace) => unawaited(
          CrashReportingService.instance.recordError(
            Reportable(error, context: 'CreatorDeleteEnforcementRepository'),
            stackTrace,
            reason: 'Creator-delete enforcement contract failure',
          ),
        ),
      );
    });
