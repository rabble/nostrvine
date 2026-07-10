// ABOUTME: Riverpod provider for the bug report / log export service.
// ABOUTME: Lives outside social_providers so it can watch the storage service
// ABOUTME: without creating an import cycle with storage_providers.

import 'package:dm_repository/dm_repository.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/storage_providers.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bug_report_providers.g.dart';

/// Bug report service for collecting diagnostics and sending encrypted
/// reports.
@riverpod
BugReportService bugReportService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);

  final nip17Service = NIP17MessageService(
    signer: nostrService.signer,
    senderPublicKey: nostrService.publicKey,
    nostrService: nostrService,
  );

  final blossomService = ref.watch(blossomUploadServiceProvider);

  return BugReportService(
    nip17MessageService: nip17Service,
    blossomUploadService: blossomService,
    errorTracker: ref.watch(errorAnalyticsTrackerProvider),
    storageManagementService: ref.watch(storageManagementServiceProvider),
  );
}
