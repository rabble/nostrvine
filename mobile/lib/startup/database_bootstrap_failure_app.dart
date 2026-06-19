import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openvine/services/database_encryption_bootstrap.dart';

/// Result of resolving the DB cipher key during app startup.
class DatabaseBootstrapStartupResult {
  const DatabaseBootstrapStartupResult._({
    required this.cipherKey,
    required this.didRenderFailureApp,
  });

  const DatabaseBootstrapStartupResult.ready(String? cipherKey)
    : this._(cipherKey: cipherKey, didRenderFailureApp: false);

  const DatabaseBootstrapStartupResult.failure()
    : this._(cipherKey: null, didRenderFailureApp: true);

  final String? cipherKey;
  final bool didRenderFailureApp;
}

/// Resolves the DB cipher key and renders a visible fail-closed startup screen
/// when bootstrap cannot complete.
Future<DatabaseBootstrapStartupResult> resolveDatabaseBootstrapForAppStart({
  required Future<String?> Function() resolveCipherKey,
  required void Function(Widget app) runApp,
  required VoidCallback removeNativeSplash,
  Future<void> Function(Object error, StackTrace stack)?
  repairLocalDatabaseCache,
  bool Function(Object error)? shouldRepairLocalDatabaseCache,
}) async {
  try {
    return DatabaseBootstrapStartupResult.ready(await resolveCipherKey());
  } catch (error, stack) {
    final shouldRepair = shouldRepairLocalDatabaseCache?.call(error) ?? false;
    if (repairLocalDatabaseCache != null && shouldRepair) {
      try {
        await repairLocalDatabaseCache(error, stack);
        return DatabaseBootstrapStartupResult.ready(await resolveCipherKey());
      } catch (_) {
        // Fall through to the final fail-closed UI below. The initial
        // bootstrap failure has already been recorded by the resolver.
      }
    }
    removeNativeSplash();
    runApp(DatabaseBootstrapFailureApp(error: error, stack: stack));
    return const DatabaseBootstrapStartupResult.failure();
  }
}

class DatabaseBootstrapFailureApp extends StatelessWidget {
  const DatabaseBootstrapFailureApp({
    required this.error,
    required this.stack,
    this.onCloseApp = SystemNavigator.pop,
    super.key,
  });

  final Object error;
  final StackTrace stack;
  final VoidCallback onCloseApp;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const DivineIcon(
                      icon: DivineIconName.warningCircle,
                      color: VineTheme.accentOrange,
                      size: 48,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "couldn't unlock your local database",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: VineTheme.primaryText,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Restart Divine after unlocking your device. If this '
                      'keeps happening, update the app or contact support.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: VineTheme.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.45,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Diagnostic: ${databaseBootstrapDiagnosticCode(error)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: VineTheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.35,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 24),
                    DivineButton(
                      label: 'close Divine',
                      onPressed: onCloseApp,
                      type: DivineButtonType.secondary,
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 24),
                      _DebugErrorDetails(error: error, stack: stack),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String databaseBootstrapDiagnosticCode(Object error) {
  if (error is SqlCipherUnavailableError) {
    return 'db-sqlcipher-unavailable';
  }

  final message = error.toString();
  if (message.contains('SQLCipher is not linked')) {
    return 'db-sqlcipher-unavailable';
  }
  if (message.contains('secure storage')) {
    return 'db-secure-storage';
  }
  if (message.contains('SQLITE_NOTADB') || message.contains('not a database')) {
    return 'db-cipher-mismatch';
  }
  return 'db-bootstrap-failed';
}

class _DebugErrorDetails extends StatelessWidget {
  const _DebugErrorDetails({required this.error, required this.stack});

  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VineTheme.onSurfaceDisabled),
      ),
      child: Text(
        '$error\n$stack',
        maxLines: 8,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: VineTheme.error,
          fontSize: 11,
          fontFamily: 'monospace',
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
