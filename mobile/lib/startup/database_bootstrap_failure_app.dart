import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
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
  Future<void> Function()? resetLocalDatabase,
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
    runApp(
      DatabaseBootstrapFailureApp(
        error: error,
        stack: stack,
        onResetLocalDatabase: resetLocalDatabase,
      ),
    );
    return const DatabaseBootstrapStartupResult.failure();
  }
}

// Fixed dark colors in both appearance modes. This screen replaces the whole
// app when the database cannot be unlocked, so it runs before the appearance
// setting is readable. Shared by both steps so the reset confirmation cannot
// drift away from the screen it interrupts.
const _titleStyle = TextStyle(
  color: VineTheme.primaryText,
  fontSize: 22,
  fontWeight: FontWeight.w700,
  decoration: TextDecoration.none,
);

const _bodyStyle = TextStyle(
  color: VineTheme.onSurfaceVariant,
  fontSize: 14,
  height: 1.45,
  decoration: TextDecoration.none,
);

const _diagnosticStyle = TextStyle(
  color: VineTheme.onSurfaceVariant,
  fontSize: 12,
  height: 1.35,
  decoration: TextDecoration.none,
);

/// Titles are reused as screen-reader announcements when a step replaces the
/// one before it, so they live next to each other rather than inline.
const _failureTitle = "couldn't unlock your local database";
const _confirmTitle = 'reset your local database?';
const _resetDoneTitle = 'local database reset';
const _resetFailedMessage = "That didn't work. Close Divine and try again.";

/// Ceiling on the manual reset. It renames a few files and clears
/// SharedPreferences, so anything approaching this means a platform channel is
/// wedged — better to report a failure the user can act on than to leave the
/// screen spinning behind two disabled buttons.
const _resetTimeout = Duration(seconds: 15);

/// Which step of the failure screen is currently on screen.
enum _Step { failure, confirm, done }

class DatabaseBootstrapFailureApp extends StatelessWidget {
  const DatabaseBootstrapFailureApp({
    required this.error,
    required this.stack,
    this.onCloseApp = SystemNavigator.pop,
    this.onResetLocalDatabase,
    super.key,
  });

  final Object error;
  final StackTrace stack;
  final VoidCallback onCloseApp;

  /// Backs up and clears the local database so the next launch rebuilds it.
  ///
  /// `null` hides the affordance. Even when provided it is only offered for
  /// diagnoses where the database is already unusable — see
  /// [DatabaseBootstrapDiagnosis.allowsLocalDatabaseReset].
  final Future<void> Function()? onResetLocalDatabase;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _FailureScreen(
        error: error,
        stack: stack,
        onCloseApp: onCloseApp,
        onResetLocalDatabase: onResetLocalDatabase,
      ),
    );
  }
}

class _FailureScreen extends StatefulWidget {
  const _FailureScreen({
    required this.error,
    required this.stack,
    required this.onCloseApp,
    required this.onResetLocalDatabase,
  });

  final Object error;
  final StackTrace stack;
  final VoidCallback onCloseApp;
  final Future<void> Function()? onResetLocalDatabase;

  @override
  State<_FailureScreen> createState() => _FailureScreenState();
}

class _FailureScreenState extends State<_FailureScreen> {
  _Step _step = _Step.failure;
  bool _resetting = false;
  bool _resetFailed = false;

  bool get _canReset =>
      widget.onResetLocalDatabase != null &&
      databaseBootstrapDiagnosis(
        widget.error,
      ).allowsLocalDatabaseReset;

  /// Swaps the step in place and announces it: nothing is pushed, so assistive
  /// tech gets no route change and the focused node just disappears.
  void _goTo(_Step step, String announcement) {
    setState(() {
      _step = step;
      // A previous attempt's failure banner must not greet the user on a step
      // they re-entered before trying again.
      _resetFailed = false;
    });
    _announce(announcement);
  }

  Future<void> _resetLocalDatabase() async {
    setState(() {
      _resetting = true;
      _resetFailed = false;
    });
    try {
      await widget.onResetLocalDatabase!().timeout(_resetTimeout);
    } on Object {
      // The reset can fail outright, and a wedged platform channel can hang it
      // past the timeout. Stay put and say so rather than closing on a reset
      // that did not happen — or spinning behind two disabled buttons forever.
      if (!mounted) return;
      setState(() {
        _resetting = false;
        _resetFailed = true;
      });
      _announce(_resetFailedMessage);
      return;
    }
    if (mounted) {
      setState(() {
        _step = _Step.done;
        _resetting = false;
      });
      _announce(_resetDoneTitle);
    }
    // Finishes the activity on Android. On iOS the process stays alive, which
    // is what the done step renders for.
    widget.onCloseApp();
  }

  void _announce(String message) => SemanticsService.sendAnnouncement(
    View.of(context),
    message,
    Directionality.of(context),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: switch (_step) {
                _Step.failure => _FailureView(
                  error: widget.error,
                  stack: widget.stack,
                  onCloseApp: widget.onCloseApp,
                  onResetRequested: _canReset
                      ? () => _goTo(_Step.confirm, _confirmTitle)
                      : null,
                ),
                _Step.confirm => _ResetConfirmView(
                  isResetting: _resetting,
                  didFail: _resetFailed,
                  onConfirm: _resetLocalDatabase,
                  onCancel: () => _goTo(_Step.failure, _failureTitle),
                ),
                _Step.done => _ResetDoneView(onCloseApp: widget.onCloseApp),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({
    required this.error,
    required this.stack,
    required this.onCloseApp,
    required this.onResetRequested,
  });

  final Object error;
  final StackTrace stack;
  final VoidCallback onCloseApp;
  final VoidCallback? onResetRequested;

  /// The advice and the reset offer answer the same question, so one condition
  /// decides both: unlocking and restarting is the fix for the transient
  /// keystore case, and misleading for the diagnoses a reset is offered for.
  String get _advice => onResetRequested != null
      ? "A restart won't fix this one. Resetting the local database below "
            'gives Divine a clean start — your account stays.'
      : 'Restart Divine after unlocking your device. If this '
            'keeps happening, update the app or contact support.';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DivineIcon(
          icon: DivineIconName.warningCircle,
          color: VineTheme.accentOrange,
          size: 48,
        ),
        const SizedBox(height: 20),
        const Text(
          _failureTitle,
          textAlign: TextAlign.center,
          style: _titleStyle,
        ),
        const SizedBox(height: 12),
        Text(_advice, textAlign: TextAlign.center, style: _bodyStyle),
        const SizedBox(height: 12),
        Text(
          'Diagnostic: ${databaseBootstrapDiagnosticCode(error)}',
          textAlign: TextAlign.center,
          style: _diagnosticStyle,
        ),
        const SizedBox(height: 24),
        DivineButton(
          label: 'close Divine',
          onPressed: onCloseApp,
          type: DivineButtonType.secondary,
        ),
        if (onResetRequested != null) ...[
          const SizedBox(height: 12),
          DivineButton(
            label: 'reset local database',
            onPressed: onResetRequested,
            type: DivineButtonType.link,
          ),
        ],
        if (kDebugMode) ...[
          const SizedBox(height: 24),
          _DebugErrorDetails(error: error, stack: stack),
        ],
      ],
    );
  }
}

class _ResetConfirmView extends StatelessWidget {
  const _ResetConfirmView({
    required this.isResetting,
    required this.didFail,
    required this.onConfirm,
    required this.onCancel,
  });

  final bool isResetting;
  final bool didFail;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DivineIcon(
          icon: DivineIconName.warningCircle,
          color: VineTheme.accentOrange,
          size: 48,
        ),
        const SizedBox(height: 20),
        const Text(
          _confirmTitle,
          textAlign: TextAlign.center,
          style: _titleStyle,
        ),
        const SizedBox(height: 12),
        const Text(
          'Your account stays. Drafts and clips saved on this device are '
          'deleted — messages and feeds come back from the network.',
          textAlign: TextAlign.center,
          style: _bodyStyle,
        ),
        if (didFail) ...[
          const SizedBox(height: 12),
          Text(
            _resetFailedMessage,
            textAlign: TextAlign.center,
            style: _diagnosticStyle.copyWith(color: VineTheme.error),
          ),
        ],
        const SizedBox(height: 24),
        DivineButton(
          label: 'reset and close',
          onPressed: isResetting ? null : onConfirm,
          isLoading: isResetting,
          type: DivineButtonType.error,
        ),
        const SizedBox(height: 12),
        DivineButton(
          label: 'cancel',
          onPressed: isResetting ? null : onCancel,
          type: DivineButtonType.secondary,
        ),
      ],
    );
  }
}

/// Terminal step after a successful reset.
///
/// Only ever seen where [DatabaseBootstrapFailureApp.onCloseApp] did not end
/// the process — on iOS `SystemNavigator.pop` cannot close the app, so without
/// this step the confirmation would sit there spinning behind two disabled
/// buttons with nothing left to happen.
class _ResetDoneView extends StatelessWidget {
  const _ResetDoneView({required this.onCloseApp});

  final VoidCallback onCloseApp;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DivineIcon(
          icon: DivineIconName.checkCircle,
          color: VineTheme.success,
          size: 48,
        ),
        const SizedBox(height: 20),
        const Text(
          _resetDoneTitle,
          textAlign: TextAlign.center,
          style: _titleStyle,
        ),
        const SizedBox(height: 12),
        const Text(
          'Close Divine and open it again — the next launch builds a fresh '
          'local database.',
          textAlign: TextAlign.center,
          style: _bodyStyle,
        ),
        const SizedBox(height: 24),
        DivineButton(
          label: 'close Divine',
          onPressed: onCloseApp,
          type: DivineButtonType.secondary,
        ),
      ],
    );
  }
}

/// Why the startup database bootstrap failed, as shown on the failure screen.
enum DatabaseBootstrapDiagnosis {
  /// The active SQLite build has no cipher — a build misconfiguration.
  cipherUnavailable('db-cipher-unavailable'),

  /// The keystore holding the cipher key was unreachable, most often a launch
  /// before the device's first unlock.
  secureStorage('db-secure-storage'),

  /// The key no longer opens the database file.
  cipherMismatch('db-cipher-mismatch'),

  /// The database file is structurally corrupt — neither readable plaintext nor
  /// recognizably encrypted.
  databaseUnreadable('db-unreadable'),

  /// Anything else. Read the exception from Crashlytics for this one.
  bootstrapFailed('db-bootstrap-failed');

  const DatabaseBootstrapDiagnosis(this.code);

  /// Short identifier rendered on the screen, so a support report names the
  /// cause without a stack trace.
  final String code;

  /// Whether the screen may offer the destructive local-database reset.
  ///
  /// [cipherMismatch] is provably unusable — the key no longer opens the file.
  /// [databaseUnreadable] is too: the file is structurally corrupt, and no key
  /// or retry changes that. [bootstrapFailed] is only presumed unusable:
  /// the cause is unknown, though startup did fail on it. The reset keeps the
  /// cipher key for exactly that reason, so the backup it leaves behind stays
  /// readable if the presumption was wrong.
  ///
  /// [secureStorage] must never reach it: the database is intact and only its
  /// keystore was unreachable, so clearing it would trade a restart-and-retry
  /// for permanent loss of every local-only draft and clip.
  /// [cipherUnavailable] cannot be helped either — without a cipher, a fresh
  /// database could not be created any more than the old one could be opened.
  ///
  /// Switched exhaustively on purpose: a future diagnosis has to make this
  /// choice deliberately instead of defaulting into a destructive offer.
  bool get allowsLocalDatabaseReset => switch (this) {
    cipherMismatch || databaseUnreadable || bootstrapFailed => true,
    cipherUnavailable || secureStorage => false,
  };
}

/// Classifies a bootstrap failure so the screen can name the cause and decide
/// whether a reset is safe to offer.
///
/// Match on error TYPE wherever the bootstrap owns the throw. The
/// secure-storage case used to be detected by looking for `secure storage` in
/// the message, which no error ever contains: `flutter_secure_storage` raises
/// a `PlatformException` carrying a platform status code. Every locked-keychain
/// failure was therefore reported as the `db-bootstrap-failed` catch-all —
/// the one code that tells a reader nothing.
DatabaseBootstrapDiagnosis databaseBootstrapDiagnosis(Object error) {
  if (error is DatabaseCipherUnavailableError) {
    return DatabaseBootstrapDiagnosis.cipherUnavailable;
  }
  if (error is DatabaseCipherStorageUnavailableException) {
    return DatabaseBootstrapDiagnosis.secureStorage;
  }
  if (error is DatabaseUnreadableError) {
    return DatabaseBootstrapDiagnosis.databaseUnreadable;
  }

  final message = error.toString();
  if (message.contains('SQLite3MultipleCiphers is not active')) {
    return DatabaseBootstrapDiagnosis.cipherUnavailable;
  }
  if (message.contains('SQLITE_NOTADB') || message.contains('not a database')) {
    return DatabaseBootstrapDiagnosis.cipherMismatch;
  }
  return DatabaseBootstrapDiagnosis.bootstrapFailed;
}

/// The short diagnostic code for [error], as rendered on the failure screen.
String databaseBootstrapDiagnosticCode(Object error) =>
    databaseBootstrapDiagnosis(error).code;

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
