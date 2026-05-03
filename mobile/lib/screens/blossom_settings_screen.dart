// ABOUTME: Settings screen for configuring Blossom media server uploads
// ABOUTME: Allows users to enable Blossom uploads and configure their preferred server

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:unified_logger/unified_logger.dart';

class BlossomSettingsScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'blossom-settings';

  /// Path for this route.
  static const path = '/blossom-settings';

  const BlossomSettingsScreen({super.key});

  @override
  ConsumerState<BlossomSettingsScreen> createState() =>
      _BlossomSettingsScreenState();
}

class _BlossomSettingsScreenState extends ConsumerState<BlossomSettingsScreen> {
  final _serverController = TextEditingController();
  bool _isBlossomEnabled = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final blossomService = ref.read(blossomUploadServiceProvider);

      final isEnabled = await blossomService.isBlossomEnabled();
      final serverUrl = await blossomService.getBlossomServer();

      if (mounted) {
        setState(() {
          _isBlossomEnabled = isEnabled;
          _serverController.text = serverUrl ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      Log.error(
        'Failed to load Blossom settings: $e',
        name: 'BlossomSettingsScreen',
        category: LogCategory.ui,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    // Validate URL if Blossom is enabled
    if (_isBlossomEnabled && _serverController.text.isNotEmpty) {
      final uri = Uri.tryParse(_serverController.text);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.blossomValidServerUrl),
            backgroundColor: VineTheme.error,
          ),
        );
        return;
      }
      // Reject non-loopback http:// — release native transport security
      // (#3358 / PR #3788) blocks the upload at the OS layer with no
      // user-facing hint. Loopback http:// (10.0.2.2, localhost,
      // 127.0.0.1) keeps working for the local Docker stack — mirrors
      // the allowlist pinned in the native configs.
      final scheme = uri.scheme.toLowerCase();
      final host = uri.host.toLowerCase();
      final isLoopbackHttp =
          scheme == 'http' &&
          (host == '10.0.2.2' || host == 'localhost' || host == '127.0.0.1');
      if (scheme != 'https' && !isLoopbackHttp) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.blossomServerUrlMustUseHttps),
            backgroundColor: VineTheme.error,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final blossomService = ref.read(blossomUploadServiceProvider);

      // Save settings
      await blossomService.setBlossomEnabled(_isBlossomEnabled);

      if (_isBlossomEnabled && _serverController.text.isNotEmpty) {
        await blossomService.setBlossomServer(_serverController.text);
      } else {
        await blossomService.setBlossomServer(null);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.blossomSettingsSaved,
              style: const TextStyle(color: VineTheme.whiteText),
            ),
            backgroundColor: VineTheme.vineGreen,
          ),
        );
        context.pop();
      }
    } catch (e) {
      Log.error(
        'Failed to save Blossom settings: $e',
        name: 'BlossomSettingsScreen',
        category: LogCategory.ui,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.blossomFailedToSaveSettings('$e')),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.nostrSettingsMediaServers,
        showBackButton: true,
        onBackPressed: context.pop,
        actions: _isLoading
            ? const []
            : [
                DiVineAppBarAction(
                  icon: SvgIconSource(DivineIconName.check.assetPath),
                  onPressed: _isSaving ? null : _saveSettings,
                  tooltip: context.l10n.blossomSaveTooltip,
                ),
              ],
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Info card
                    Card(
                      color: VineTheme.backgroundColor.withValues(alpha: 0.7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: VineTheme.vineGreen.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: VineTheme.vineGreen.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  context.l10n.blossomAboutTitle,
                                  style: const TextStyle(
                                    color: VineTheme.vineGreen,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.l10n.blossomAboutDescription,
                              style: const TextStyle(
                                color: VineTheme.onSurface,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Enable/Disable toggle
                    SwitchListTile(
                      title: Text(
                        context.l10n.blossomUseCustomServer,
                        style: const TextStyle(
                          color: VineTheme.whiteText,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        _isBlossomEnabled
                            ? context.l10n.blossomCustomServerEnabledSubtitle
                            : context.l10n.blossomCustomServerDisabledSubtitle,
                        style: const TextStyle(color: VineTheme.onSurfaceMuted),
                      ),
                      value: _isBlossomEnabled,
                      onChanged: (value) {
                        setState(() {
                          _isBlossomEnabled = value;
                        });
                      },
                      activeThumbColor: VineTheme.vineGreen,
                      inactiveThumbColor: VineTheme.lightText,
                      inactiveTrackColor: VineTheme.lightText.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Server URL input (only shown when custom server is enabled)
                    if (_isBlossomEnabled) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.blossomCustomServerUrl,
                            style: const TextStyle(
                              color: VineTheme.whiteText,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _serverController,
                            style: const TextStyle(color: VineTheme.whiteText),
                            decoration: InputDecoration(
                              hintText: 'https://blossom.band',
                              hintStyle: const TextStyle(
                                color: VineTheme.onSurfaceDisabled,
                              ),
                              filled: true,
                              fillColor: VineTheme.whiteText.withValues(
                                alpha: 0.1,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: VineTheme.vineGreen.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: VineTheme.vineGreen.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: VineTheme.vineGreen,
                                ),
                              ),
                              prefixIcon: const Icon(
                                Icons.cloud_upload,
                                color: VineTheme.vineGreen,
                              ),
                            ),
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.blossomCustomServerHelper,
                            style: const TextStyle(
                              color: VineTheme.onSurfaceMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // Popular Blossom servers section
                      Text(
                        context.l10n.blossomPopularServers,
                        style: const TextStyle(
                          color: VineTheme.whiteText,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildServerOption(
                        'https://blossom.band',
                        'Blossom Band',
                      ),
                      _buildServerOption(
                        'https://cdn.satellite.earth',
                        'Satellite Earth',
                      ),
                      _buildServerOption(
                        'https://blossom.primal.net',
                        'Primal',
                      ),
                      _buildServerOption(
                        'https://nostr.download',
                        'Nostr Download',
                      ),
                      _buildServerOption(
                        'https://cdn.nostrcheck.me',
                        'NostrCheck',
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildServerOption(String url, String name) {
    return Card(
      color: VineTheme.whiteText.withValues(alpha: 0.05),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(name, style: const TextStyle(color: VineTheme.whiteText)),
        subtitle: Text(
          url,
          style: const TextStyle(color: VineTheme.onSurfaceMuted, fontSize: 12),
        ),
        trailing: const Icon(Icons.arrow_forward, color: VineTheme.vineGreen),
        onTap: () {
          setState(() {
            _serverController.text = url;
          });
        },
      ),
    );
  }
}
