// ABOUTME: Keycast-held private key export card for the Key Management screen
// ABOUTME: Password-confirmed fetch of the nsec Divine's login service holds

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/utils/clipboard_utils.dart';

/// Shown in place of the local "Copy My Private Key (nsec)" action for an
/// account whose key Keycast holds.
///
/// The key is not on this device and NIP-46 defines no method that returns key
/// material, so it comes from Keycast's own export endpoint, authorized by the
/// session's bearer token plus the account password. Keycast keeps both
/// preconditions server-side — a verified email, and the `verified_minor`
/// custody refusal — so nothing here is a way around them.
///
/// Nothing is stored: the key goes from the response to the sheet that shows
/// it and to the clipboard the user asked for, and is never written to disk or
/// logged.
class KeycastKeyExportCard extends ConsumerWidget {
  const KeycastKeyExportCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VineTheme.vineGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VineTheme.vineGreen.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Row(
            children: [
              const DivineIcon(
                icon: DivineIconName.key,
                color: VineTheme.vineGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.keyManagementKeycastRemoteSigning,
                  style: VineTheme.bodyMediumFont(
                    color: VineTheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          DivineButton(
            label: context.l10n.keyManagementCopyNsec,
            leadingIcon: DivineIconName.copy,
            type: DivineButtonType.secondary,
            size: DivineButtonSize.small,
            onPressed: () => _copyKeycastKey(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _copyKeycastKey(BuildContext context, WidgetRef ref) async {
    // Consistency guard with the other two key-boundary call sites. A flip to
    // restricted unmounts this card, so there is no real window here; kept so
    // every handover site reads the gate. Keycast refuses a minor's export
    // server-side too, so this is defense in depth rather than the gate itself.
    if (ref.read(isKeyManagementRestrictedProvider)) return;

    final result = await VineBottomSheet.show<ExportKeyResult>(
      context: context,
      scrollable: false,
      expanded: false,
      // Fixed mode otherwise derives isScrollControlled from `expanded`, which
      // caps the sheet's height and leaves it wholly behind the keyboard.
      isScrollControlled: true,
      // A `body` sheet never renders `contentTitle` — that is read only on the
      // `children` path — so the title goes through the header instead, which
      // also supplies the spacing below the divider.
      title: Text(context.l10n.keyManagementCopyNsec),
      body: const _KeycastKeyExportFlow(),
    );

    // The sheet returns a value only when it has a refusal to report: a wrong
    // password stays inline, and on success the key is shown and copied inside
    // the sheet, so neither comes back here.
    if (result == null || !context.mounted) return;

    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        _failureMessage(l10n, result.failure),
        error: true,
      ),
    );
  }

  /// Map a refusal to copy the user can act on.
  ///
  /// Takes the enum rather than the whole result so the server's prose cannot
  /// reach the screen: [ExportKeyResult.error] is written for the web UI, is
  /// never translated, and for a transport failure it is the raw exception.
  /// It stays in the logs.
  String _failureMessage(AppLocalizations l10n, ExportKeyFailure? failure) {
    return switch (failure) {
      ExportKeyFailure.needsSignIn => l10n.keyManagementKeycastSignInAgain,
      ExportKeyFailure.emailUnverified =>
        l10n.keyManagementKeycastEmailUnverified,
      ExportKeyFailure.denied => l10n.keyManagementKeycastDenied,
      ExportKeyFailure.rateLimited => l10n.keyManagementKeycastRateLimited,
      // A definitive "there is no key" is not a failure to reach the service,
      // and unlike the generic arm no retry will change it.
      ExportKeyFailure.noKey => l10n.keyManagementKeycastNoKey,
      _ => l10n.keyManagementExportFailed(
        l10n.keyManagementKeycastGenericFailure,
      ),
    };
  }
}

/// The two steps behind the export: confirm the account password, then show the
/// key it returned.
///
/// The export runs here rather than in the caller so a wrong password can stay
/// inline — the field keeps its place and contents, and the retry costs one
/// keystroke instead of a reopen. Any refusal a retry cannot clear pops with the
/// result for the caller to report.
///
/// The key is shown rather than only copied, because a device that blocks
/// clipboard access would otherwise leave the owner with no way to reach it. It
/// is hidden behind the field's own reveal control by default, and lives only in
/// a controller that is disposed with the sheet — never written to disk, cached,
/// or logged. Same for the password.
class _KeycastKeyExportFlow extends ConsumerStatefulWidget {
  const _KeycastKeyExportFlow();

  @override
  ConsumerState<_KeycastKeyExportFlow> createState() =>
      _KeycastKeyExportFlowState();
}

class _KeycastKeyExportFlowState extends ConsumerState<_KeycastKeyExportFlow> {
  /// Gap kept between a raised keyboard and the sheet, mirroring the clearance
  /// `VineBottomSheet` applies to its own bottom input: reported keyboard height
  /// varies while typing, and a flush edge puts the actions under the keyboard.
  static const double _keyboardClearance = 12;

  /// Wrong passwords this sheet will take before it stops accepting them.
  ///
  /// Keycast does not rate-limit `POST /user/export-key` and writes no audit
  /// record for it, so an uncapped retry loop turns a borrowed unlocked phone
  /// into a password oracle that pays out the account's nsec. Reopening the
  /// sheet clears the count — this is friction, not a lockout, and the durable
  /// fix is server-side.
  static const int _maxAttempts = 5;

  final _passwordController = TextEditingController();
  final _keyController = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  /// Wrong passwords submitted so far, against [_maxAttempts].
  int _wrongPasswords = 0;

  /// True once [_maxAttempts] is spent: the field and the submit action stay
  /// disabled until the sheet is dismissed.
  bool _lockedOut = false;

  /// True once the key has been fetched, which swaps the password step for the
  /// reveal step.
  bool _fetched = false;

  @override
  void dispose() {
    _passwordController.dispose();
    // Drops the only in-memory copy of the key material with the sheet.
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_lockedOut) return;

    final password = _passwordController.text;
    final l10n = context.l10n;

    if (password.isEmpty) {
      setState(() => _errorText = l10n.authPasswordRequired);
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final result = await ref
        .read(authServiceProvider)
        .exportKeycastNsec(password);

    if (!mounted) return;

    if (result.success && result.key != null) {
      setState(() {
        _submitting = false;
        _keyController.text = result.key!;
        _fetched = true;
        // The password has done its job; do not keep it alive behind the
        // revealed key.
        _passwordController.clear();
      });
      return;
    }

    // Wrong password is the one failure worth staying open for; anything else
    // needs a different action than "type it again". Retrying is capped so the
    // sheet is not an unlimited guessing loop against an endpoint that hands
    // back the nsec.
    if (result.failure == ExportKeyFailure.wrongPassword) {
      _wrongPasswords++;
      final lockedOut = _wrongPasswords >= _maxAttempts;
      setState(() {
        _submitting = false;
        _lockedOut = lockedOut;
        _errorText = lockedOut
            ? l10n.keyManagementKeycastTooManyAttempts
            : l10n.keyManagementKeycastWrongPassword;
      });
      return;
    }

    // The sheet is a Navigator route, so pop it through the Navigator that
    // owns it rather than GoRouter — the modal is not part of the route tree.
    Navigator.of(context).pop(result);
  }

  Future<void> _copyKey() async {
    await ClipboardUtils.copy(
      context,
      _keyController.text,
      message: context.l10n.keyManagementExportSuccess,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        bottom: keyboardInset > 0 ? keyboardInset + _keyboardClearance : 0,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _fetched
            ? _RevealStep(
                controller: _keyController,
                onCopy: _copyKey,
                onClose: () => Navigator.of(context).pop(),
              )
            : _PasswordStep(
                controller: _passwordController,
                errorText: _errorText,
                submitting: _submitting,
                lockedOut: _lockedOut,
                onSubmit: _submit,
                onCancel: () => Navigator.of(context).pop(),
                // Clear a stale "wrong password" as soon as the user edits, so
                // the error refers to the attempt rather than the previous one.
                // A spent attempt budget is not stale, so it stays put.
                onEdited: () {
                  if (_errorText != null && !_lockedOut) {
                    setState(() => _errorText = null);
                  }
                },
              ),
      ),
    );
  }
}

/// Step one: confirm the account password.
class _PasswordStep extends StatelessWidget {
  const _PasswordStep({
    required this.controller,
    required this.errorText,
    required this.submitting,
    required this.lockedOut,
    required this.onSubmit,
    required this.onCancel,
    required this.onEdited,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool submitting;
  final bool lockedOut;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final VoidCallback onEdited;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final blocked = submitting || lockedOut;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        Text(
          l10n.keyManagementKeycastPasswordPrompt,
          style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceVariant),
        ),
        DivineAuthTextField(
          label: l10n.authPasswordLabel,
          controller: controller,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          errorText: errorText,
          enabled: !blocked,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!blocked) onSubmit();
          },
          onChanged: (_) => onEdited(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: 8,
          children: [
            DivineButton(
              label: l10n.commonCancel,
              type: DivineButtonType.tertiary,
              size: DivineButtonSize.small,
              onPressed: submitting ? null : onCancel,
            ),
            // Fetches the key and moves to the reveal step; copying is that
            // step's action, so neither this label nor its icon may promise it.
            DivineButton(
              label: l10n.keyManagementKeycastFetchKey,
              leadingIcon: DivineIconName.key,
              size: DivineButtonSize.small,
              isLoading: submitting,
              onPressed: blocked ? null : onSubmit,
            ),
          ],
        ),
      ],
    );
  }
}

/// Step two: hand over the key that came back.
class _RevealStep extends StatelessWidget {
  const _RevealStep({
    required this.controller,
    required this.onCopy,
    required this.onClose,
  });

  final TextEditingController controller;
  final VoidCallback onCopy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        // Read-only: the field is a viewer for the fetched key, and its own
        // reveal control is what un-hides it.
        DivineAuthTextField(
          label: l10n.keyManagementYourPrivateKeyLabel,
          controller: controller,
          obscureText: true,
          readOnly: true,
          autocorrect: false,
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VineTheme.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: VineTheme.error.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const DivineIcon(
                icon: DivineIconName.warning,
                color: VineTheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.keyManagementNeverShare,
                  style: VineTheme.bodyMediumFont(
                    color: VineTheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: 8,
          children: [
            DivineButton(
              label: l10n.commonClose,
              type: DivineButtonType.tertiary,
              size: DivineButtonSize.small,
              onPressed: onClose,
            ),
            DivineButton(
              label: l10n.keyManagementKeycastCopyKey,
              leadingIcon: DivineIconName.copy,
              size: DivineButtonSize.small,
              onPressed: onCopy,
            ),
          ],
        ),
      ],
    );
  }
}
