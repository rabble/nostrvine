// ABOUTME: Times one startup task and logs how long it took
// ABOUTME: Shared by the startup coordinator and the bootstrap sequence

import 'dart:async';

import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/startup_performance_service.dart';

Future<void> runTimedStartupTask({
  required String phaseName,
  required String initializationStep,
  required Future<void> Function() task,
  required StartupPerformanceService startupPerformance,
  required CrashReportingService crashReporting,
}) async {
  startupPerformance.startPhase(phaseName);
  crashReporting.logInitializationStep(initializationStep);
  try {
    await task();
  } finally {
    startupPerformance.completePhase(phaseName);
  }
}
