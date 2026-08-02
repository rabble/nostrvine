// ABOUTME: Key management screen for importing, exporting, and backing up Nostr keys
// ABOUTME: Simple, clear interface focused on user needs with helpful explanations

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/screens/key_management/keycast_key_export_card.dart';

class KeyManagementScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'key-management';

  /// Path for this route.
  static const path = '/key-management';

  const KeyManagementScreen({super.key});

  @override
  ConsumerState<KeyManagementScreen> createState() =>
      _KeyManagementScreenState();
}

class _KeyManagementScreenState extends ConsumerState<KeyManagementScreen> {
  bool _isProcessing = false;
  final _importController = TextEditingController();

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nostrService = ref.watch(nostrServiceProvider);
    final restricted = ref.watch(isKeyManagementRestrictedProvider);

    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.keyManagementTitle,
        showBackButton: true,
        onBackPressed: context.safePop,
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: .fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              const _NpubDisplayBlock(),
              const SizedBox(height: 24),

              // What are Nostr keys explanation
              _buildExplanationCard(),
              const SizedBox(height: 24),

              // Protected minors (#182) cannot export their nsec or swap the
              // account to a self-held key; the affordances are replaced by an
              // explanatory locked card. Fails closed via
              // isKeyManagementRestrictedProvider.
              if (restricted)
                const _KeyManagementLockedCard()
              else ...[
                // Import existing key section
                _buildImportSection(context, nostrService),
                const SizedBox(height: 24),

                // Export/Backup section
                _buildExportSection(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExplanationCard() {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VineTheme.vineGreen.withValues(alpha: 0.15),
        border: Border.all(color: VineTheme.vineGreen.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DivineIcon(
                icon: DivineIconName.info,
                color: VineTheme.vineGreen,
              ),
              const SizedBox(width: 12),
              Text(
                l10n.keyManagementWhatAreKeys,
                style: VineTheme.titleSmallFont(color: VineTheme.vineGreen),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.keyManagementExplanation,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportSection(BuildContext context, nostrService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.keyManagementImportTitle,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.keyManagementImportSubtitle,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: context.vineColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.vineColors.card),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DivineTextField(
                controller: _importController,
                labelText: 'nsec1...',
                minLines: 1,
                maxLines: 3,
                enabled: !_isProcessing,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                spellCheckConfiguration:
                    const SpellCheckConfiguration.disabled(),
                filled: true,
                suffixIcon: DivineIconButton(
                  icon: DivineIconName.clipboard,
                  size: DivineIconButtonSize.small,
                  backgroundColor: VineTheme.transparent,
                  foregroundColor: context.vineColors.onSurfaceVariant,
                  showShadow: false,
                  tooltip: context.l10n.keyManagementPasteKey,
                  onPressed: _isProcessing ? null : _pasteKeyFromClipboard,
                ),
              ),
              const SizedBox(height: 16),
              DivineButton(
                label: context.l10n.keyManagementImportButton,
                expanded: true,
                isLoading: _isProcessing,
                onPressed: _isProcessing
                    ? null
                    : () => _importKey(context, nostrService),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VineTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: VineTheme.warning.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const DivineIcon(
                      icon: DivineIconName.warning,
                      color: VineTheme.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.keyManagementImportWarning,
                        style: VineTheme.bodySmallFont(
                          color: context.vineColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExportSection(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final canExportLocalNsec = authService.canExportLocalNsec;
    final showKeycastRemoteSigningInfo =
        !canExportLocalNsec &&
        authService.authenticationSource == AuthenticationSource.divineOAuth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.keyManagementBackupTitle,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.keyManagementBackupSubtitle,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: context.vineColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.vineColors.card),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (canExportLocalNsec) ...[
                DivineButton(
                  label: context.l10n.keyManagementCopyNsec,
                  leadingIcon: DivineIconName.copy,
                  expanded: true,
                  onPressed: _isProcessing ? null : () => _exportKey(context),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VineTheme.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: VineTheme.error.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const DivineIcon(
                        icon: DivineIconName.shieldCheck,
                        color: VineTheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.keyManagementNeverShare,
                          style: VineTheme.bodySmallFont(
                            color: context.vineColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (showKeycastRemoteSigningInfo)
                const KeycastKeyExportCard(),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pasteKeyFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _importController.text = text;
  }

  Future<void> _importKey(BuildContext context, nostrService) async {
    final nsec = _importController.text.trim();

    if (nsec.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.keyManagementPasteKey,
          error: true,
        ),
      );
      return;
    }

    if (!nsec.startsWith('nsec1')) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.keyManagementInvalidFormat,
          error: true,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await VineBottomSheet.show<bool>(
      context: context,
      scrollable: false,
      contentTitle: context.l10n.keyManagementConfirmImportTitle,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            context.l10n.keyManagementConfirmImportBody,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            spacing: 16,
            children: [
              Expanded(
                child: DivineButton(
                  label: context.l10n.reportCancel,
                  type: DivineButtonType.secondary,
                  expanded: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              Expanded(
                child: DivineButton(
                  label: context.l10n.keyManagementImportConfirm,
                  expanded: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      // Use AuthService for proper session setup and relay discovery
      final authService = ref.read(authServiceProvider);
      // Re-check the protected-minor gate at the raw-key boundary: the
      // render-time gate in build() can flip to restricted while the
      // confirmation dialog above is open, and AuthService is policy-unaware.
      if (ref.read(isKeyManagementRestrictedProvider)) return;
      final result = await authService.importFromNsec(nsec);

      if (!result.success) {
        throw Exception(result.errorMessage ?? 'Failed to import key');
      }

      // Fetch profile after successful import (authService is source of truth)
      if (context.mounted && authService.currentPublicKeyHex != null) {
        try {
          await ref
              .read(profileRepositoryProvider)
              ?.fetchFreshProfile(pubkey: authService.currentPublicKeyHex!);
        } catch (e) {
          // Non-fatal - profile fetch failure shouldn't block import
        }
      }

      if (context.mounted) {
        _importController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.keyManagementImportSuccess,
            duration: const Duration(seconds: 3),
          ),
        );

        context.safePop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.keyManagementImportFailed(e),
            error: true,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _exportKey(BuildContext context) async {
    try {
      // Consistency guard with _importKey's raw-key boundary check. No dialog
      // precedes this call, so there is no real flip window here; kept as
      // defense-in-depth so both key-handover call sites read the gate.
      if (ref.read(isKeyManagementRestrictedProvider)) return;
      final nsec = await ref.read(authServiceProvider).exportNsec();

      if (nsec == null) {
        throw Exception('No private key available to export.');
      }

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: nsec));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.keyManagementExportSuccess,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.keyManagementExportFailed(e),
            error: true,
          ),
        );
      }
    }
  }
}

class _NpubDisplayBlock extends ConsumerWidget {
  const _NpubDisplayBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final npub = ref.watch(authServiceProvider).currentNpub ?? '';

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.keyManagementYourPublicKeyLabel,
                  style: VineTheme.labelMediumFont(
                    color: context.vineColors.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  npub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          DivineIconButton(
            icon: DivineIconName.copy,
            backgroundColor: VineTheme.transparent,
            foregroundColor: context.vineColors.onSurface,
            showShadow: false,
            tooltip: l10n.keyManagementCopyPublicKeyTooltip,
            onPressed: () => _copyNpub(context, npub),
          ),
        ],
      ),
    );
  }

  Future<void> _copyNpub(BuildContext context, String npub) async {
    final l10n = context.l10n;
    await Clipboard.setData(ClipboardData(text: npub));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(l10n.keyManagementPublicKeyCopied),
    );
  }
}

/// Shown in place of the key backup/export and import sections for a protected
/// minor (#182): the account's keys are custodially managed, so those
/// affordances are removed. The npub display and the key explanation stay.
class _KeyManagementLockedCard extends StatelessWidget {
  const _KeyManagementLockedCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VineTheme.vineGreen.withValues(alpha: 0.15),
        border: Border.all(color: VineTheme.vineGreen.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DivineIcon(
            icon: DivineIconName.shieldCheck,
            color: VineTheme.vineGreen,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text(
                  l10n.keyManagementRestrictedTitle,
                  style: VineTheme.titleSmallFont(color: VineTheme.vineGreen),
                ),
                Text(
                  l10n.keyManagementRestrictedBody,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
