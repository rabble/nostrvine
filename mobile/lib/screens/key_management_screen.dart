// ABOUTME: Key management screen for importing, exporting, and backing up Nostr keys
// ABOUTME: Simple, clear interface focused on user needs with helpful explanations

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';

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

    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.keyManagementTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
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
              // What are Nostr keys explanation
              _buildExplanationCard(),
              const SizedBox(height: 24),

              // Import existing key section
              _buildImportSection(context, nostrService),
              const SizedBox(height: 24),

              // Export/Backup section
              _buildExportSection(context),
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
              const Icon(
                Icons.info_outline,
                color: VineTheme.vineGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                l10n.keyManagementWhatAreKeys,
                style: const TextStyle(
                  color: VineTheme.vineGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.keyManagementExplanation,
            style: const TextStyle(
              color: VineTheme.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
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
          style: const TextStyle(
            color: VineTheme.whiteText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.keyManagementImportSubtitle,
          style: const TextStyle(
            color: VineTheme.onSurfaceMuted,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: VineTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: VineTheme.cardBackground),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _importController,
                style: const TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'nsec1...',
                  hintStyle: const TextStyle(color: VineTheme.lightText),
                  filled: true,
                  fillColor: VineTheme.backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: VineTheme.cardBackground,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: VineTheme.cardBackground,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: VineTheme.vineGreen),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.paste,
                      color: VineTheme.secondaryText,
                    ),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        _importController.text = data!.text!.trim();
                      }
                    },
                  ),
                ),
                maxLines: 3,
                enabled: !_isProcessing,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () => _importKey(context, nostrService),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VineTheme.vineGreen,
                    foregroundColor: VineTheme.whiteText,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: VineTheme.whiteText,
                          ),
                        )
                      : Text(
                          context.l10n.keyManagementImportButton,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
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
                    const Icon(
                      Icons.warning_amber,
                      color: VineTheme.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.keyManagementImportWarning,
                        style: const TextStyle(
                          color: VineTheme.onSurfaceVariant,
                          fontSize: 13,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.keyManagementBackupTitle,
          style: const TextStyle(
            color: VineTheme.whiteText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.keyManagementBackupSubtitle,
          style: const TextStyle(
            color: VineTheme.onSurfaceMuted,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: VineTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: VineTheme.cardBackground),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : () => _exportKey(context),
                  icon: const Icon(Icons.copy, size: 20),
                  label: Text(
                    context.l10n.keyManagementCopyNsec,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VineTheme.vineGreen,
                    foregroundColor: VineTheme.whiteText,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
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
                    const Icon(
                      Icons.security,
                      color: VineTheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.keyManagementNeverShare,
                        style: const TextStyle(
                          color: VineTheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
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

  Future<void> _importKey(BuildContext context, nostrService) async {
    final nsec = _importController.text.trim();

    if (nsec.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.keyManagementPasteKey),
          backgroundColor: VineTheme.warning,
        ),
      );
      return;
    }

    if (!nsec.startsWith('nsec1')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.keyManagementInvalidFormat),
          backgroundColor: VineTheme.error,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: Text(
          dialogContext.l10n.keyManagementConfirmImportTitle,
          style: const TextStyle(color: VineTheme.whiteText),
        ),
        content: Text(
          dialogContext.l10n.keyManagementConfirmImportBody,
          style: const TextStyle(color: VineTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: Text(
              dialogContext.l10n.reportCancel,
              style: const TextStyle(color: VineTheme.vineGreen),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.vineGreen,
            ),
            onPressed: () => dialogContext.pop(true),
            child: Text(dialogContext.l10n.keyManagementImportConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      // Use AuthService for proper session setup and relay discovery
      final authService = ref.read(authServiceProvider);
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
          SnackBar(
            content: Text(context.l10n.keyManagementImportSuccess),
            backgroundColor: VineTheme.vineGreen,
            duration: const Duration(seconds: 3),
          ),
        );

        // Pop back to settings after successful import
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.keyManagementImportFailed(e)),
            backgroundColor: VineTheme.error,
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
      final nsec = await ref.read(authServiceProvider).exportNsec();

      if (nsec == null) {
        throw Exception('No private key available to export.');
      }

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: nsec));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.keyManagementExportSuccess),
            backgroundColor: VineTheme.vineGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.keyManagementExportFailed(e)),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    }
  }
}
