// ABOUTME: Riverpod provider for the bug report / log export service.
// ABOUTME: Lives outside social_providers so it can watch the storage service
// ABOUTME: without creating an import cycle with storage_providers.

import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/storage_providers.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bug_report_providers.g.dart';

/// Bug report service for collecting diagnostics and exporting logs.
@riverpod
BugReportService bugReportService(Ref ref) {
  return BugReportService(
    errorTracker: ref.watch(errorAnalyticsTrackerProvider),
    storageManagementService: ref.watch(storageManagementServiceProvider),
  );
}
