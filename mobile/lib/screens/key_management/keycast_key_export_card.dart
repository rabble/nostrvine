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
/// Nothing is stored: the key goes from the response to the clipboard the user
/// asked for, and is never written to disk or logged.
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
      contentTitle: context.l10n.keyManagementCopyNsec,
      body: const _KeycastKeyPasswordForm(),
    );

    // Null means the user backed out. A wrong password never arrives here —
    // the sheet keeps that one inline so the field stays open to retry.
    if (result == null || !context.mounted) return;

    final l10n = context.l10n;

    if (result.success && result.key != null) {
      // ClipboardUtils owns both halves of copy-with-feedback, so this matches
      // every other copy action in the app and cannot drift from it.
      await ClipboardUtils.copy(
        context,
        result.key!,
        message: l10n.keyManagementExportSuccess,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        _failureMessage(l10n, result),
        error: true,
      ),
    );
  }

  /// Map a refusal to copy the user can act on.
  ///
  /// Branches on [ExportKeyResult.failure], never on the server's prose: that
  /// text is written for the web UI and varies by deployment.
  String _failureMessage(AppLocalizations l10n, ExportKeyResult result) {
    return switch (result.failure) {
      ExportKeyFailure.needsSignIn => l10n.keyManagementKeycastSignInAgain,
      ExportKeyFailure.emailUnverified =>
        l10n.keyManagementKeycastEmailUnverified,
      ExportKeyFailure.denied => l10n.keyManagementKeycastDenied,
      _ => l10n.keyManagementExportFailed(
        result.error ?? l10n.keyManagementKeycastGenericFailure,
      ),
    };
  }
}

/// Asks for the account password, then performs the Keycast export behind it.
///
/// The export runs here rather than in the caller so a wrong password can stay
/// inline — the field keeps focus and its contents, and the user retries
/// without reopening anything. Every other outcome pops with the result and is
/// reported by the caller.
///
/// The password lives in the controller for the life of this sheet and is never
/// stored; the key it returns is handed straight to the caller.
class _KeycastKeyPasswordForm extends ConsumerStatefulWidget {
  const _KeycastKeyPasswordForm();

  @override
  ConsumerState<_KeycastKeyPasswordForm> createState() =>
      _KeycastKeyPasswordFormState();
}

class _KeycastKeyPasswordFormState
    extends ConsumerState<_KeycastKeyPasswordForm> {
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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

    // Wrong password is the one failure worth staying open for; anything else
    // needs a different action than "type it again".
    if (result.failure == ExportKeyFailure.wrongPassword) {
      setState(() {
        _submitting = false;
        _errorText = l10n.keyManagementKeycastWrongPassword;
      });
      return;
    }

    // The sheet is a Navigator route, so pop it through the Navigator that
    // owns it rather than GoRouter — the modal is not part of the route tree.
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
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
            controller: _passwordController,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            errorText: _errorText,
            enabled: !_submitting,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitting ? null : _submit(),
            // Clear a stale "wrong password" as soon as the user edits, so the
            // error refers to the attempt rather than the previous one.
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 8,
            children: [
              DivineButton(
                label: l10n.commonCancel,
                type: DivineButtonType.tertiary,
                size: DivineButtonSize.small,
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(),
              ),
              DivineButton(
                label: l10n.keyManagementKeycastCopyKey,
                leadingIcon: DivineIconName.copy,
                size: DivineButtonSize.small,
                isLoading: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
