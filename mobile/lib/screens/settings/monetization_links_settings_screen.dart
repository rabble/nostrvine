// ABOUTME: Settings screen for profile support and subscription links.
// ABOUTME: Persists normalized outbound monetization links in Kind 0 metadata.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/features/monetization/monetization_analytics.dart';
import 'package:openvine/features/monetization/monetization_storefront_policy.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:unified_logger/unified_logger.dart';

class MonetizationLinksSettingsScreen extends ConsumerStatefulWidget {
  static const routeName = 'monetization-links-settings';
  static const subpath = 'monetization-links';
  static const path = '/settings/monetization-links';

  const MonetizationLinksSettingsScreen({super.key});

  @override
  ConsumerState<MonetizationLinksSettingsScreen> createState() =>
      _MonetizationLinksSettingsScreenState();
}

class _MonetizationLinksSettingsScreenState
    extends ConsumerState<MonetizationLinksSettingsScreen> {
  late final Map<MonetizationLinkProvider, TextEditingController> _controllers;
  late final Map<MonetizationLinkProvider, bool> _enabled;
  final _errors = <MonetizationLinkProvider, String>{};
  String? _hydratedEventId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final provider in MonetizationLinkProvider.values)
        provider: TextEditingController(),
    };
    _enabled = {
      for (final provider in MonetizationLinkProvider.values) provider: false,
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
    final profileAsync = pubkey == null
        ? const AsyncValue<UserProfile?>.data(null)
        : ref.watch(userProfileReactiveProvider(pubkey));
    final profile = profileAsync.asData?.value;
    final repository = ref.watch(profileRepositoryProvider);
    final currentProfile = pubkey == null
        ? null
        : _profileSeed(pubkey: pubkey, cachedProfile: profile);
    final canSave = !_saving && repository != null && currentProfile != null;
    final appStoreTipPolicy = usesAppleAppStoreTipPolicy;
    final providers = monetizationProvidersForCurrentStorefront();
    final tipProviders = providers
        .where((provider) => provider.category == MonetizationLinkCategory.tip)
        .toList(growable: false);
    final subscriptionProviders = providers
        .where(
          (provider) =>
              provider.category == MonetizationLinkCategory.subscription,
        )
        .toList(growable: false);
    if (profile != null && _hydratedEventId != profile.eventId) {
      _hydrate(profile);
    }

    return Scaffold(
      appBar: DiVineAppBar(
        title: appStoreTipPolicy
            ? context.l10n.monetizationTipsSettingsTitle
            : context.l10n.monetizationSettingsTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: VineTheme.surfaceBackground,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _SectionIntro(
                profile: profile,
                appStoreTipPolicy: appStoreTipPolicy,
              ),
              const SizedBox(height: 20),
              _SectionHeader(context.l10n.monetizationSettingsTipSection),
              for (final provider in tipProviders)
                _ProviderEditor(
                  provider: provider,
                  controller: _controllers[provider]!,
                  enabled: _enabled[provider] ?? false,
                  errorText: _errors[provider],
                  onEnabledChanged: (value) =>
                      setState(() => _enabled[provider] = value),
                  onChanged: (_) {
                    if (_errors.remove(provider) != null) setState(() {});
                  },
                ),
              if (subscriptionProviders.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionHeader(
                  context.l10n.monetizationSettingsSubscriptionSection,
                ),
                for (final provider in subscriptionProviders)
                  _ProviderEditor(
                    provider: provider,
                    controller: _controllers[provider]!,
                    enabled: _enabled[provider] ?? false,
                    errorText: _errors[provider],
                    onEnabledChanged: (value) =>
                        setState(() => _enabled[provider] = value),
                    onChanged: (_) {
                      if (_errors.remove(provider) != null) setState(() {});
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: VineTheme.surfaceBackground,
            border: Border(top: BorderSide(color: VineTheme.outlineMuted)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: DivineButton(
                  label: _saving
                      ? context.l10n.monetizationSettingsSaving
                      : appStoreTipPolicy
                      ? context.l10n.monetizationTipsSettingsSave
                      : context.l10n.monetizationSettingsSave,
                  leadingIcon: .check,
                  expanded: true,
                  onPressed: canSave ? () => _save(currentProfile) : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  UserProfile _profileSeed({
    required String pubkey,
    required UserProfile? cachedProfile,
  }) {
    if (cachedProfile != null) return cachedProfile;
    return UserProfile(
      pubkey: pubkey,
      displayName: '',
      rawData: const {},
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      eventId: 'local-profile-seed-$pubkey',
    );
  }

  void _hydrate(UserProfile profile) {
    _hydratedEventId = profile.eventId;
    final byProvider = {
      for (final link in profile.monetizationLinks) link.provider: link,
    };
    for (final provider in MonetizationLinkProvider.values) {
      final link = byProvider[provider];
      _controllers[provider]!.text = link?.url ?? '';
      _enabled[provider] = link?.enabled ?? false;
    }
    _errors.clear();
  }

  Future<void> _save(UserProfile currentProfile) async {
    final links = <MonetizationLink>[];
    final errors = <MonetizationLinkProvider, String>{};

    for (final provider in monetizationProvidersForCurrentStorefront()) {
      final input = _controllers[provider]!.text;
      if (input.trim().isEmpty) continue;
      if (!(_enabled[provider] ?? false)) continue;
      final result = normalizeMonetizationLinkInput(
        provider: provider,
        input: input,
        enabled: true,
      );
      switch (result) {
        case MonetizationLinkInputValid(:final link):
          links.add(link);
        case MonetizationLinkInputInvalid(:final reason):
          errors[provider] = _errorTextFor(reason);
      }
    }

    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      return;
    }

    setState(() => _saving = true);
    try {
      final repository = ref.read(profileRepositoryProvider);
      if (repository == null) return;
      Log.info(
        'Saving monetization links: count=${links.length}',
        name: 'MonetizationLinksSettingsScreen',
        category: LogCategory.system,
      );
      final saved = await repository.saveProfileEvent(
        displayName: currentProfile.displayName ?? currentProfile.name ?? '',
        about: currentProfile.about,
        website: currentProfile.website,
        picture: currentProfile.picture,
        banner: currentProfile.banner,
        currentProfile: currentProfile,
        monetizationLinks: links,
      );
      if (!mounted) return;
      _hydrate(saved);
      ref
        ..invalidate(userProfileReactiveProvider(currentProfile.pubkey))
        ..invalidate(fetchUserProfileProvider(currentProfile.pubkey));
      Log.info(
        'Saved monetization links: count=${saved.enabledMonetizationLinks.length}',
        name: 'MonetizationLinksSettingsScreen',
        category: LogCategory.system,
      );
      final analytics = ref.read(analyticsEventSinkProvider);
      for (final link in links) {
        trackMonetizationLinkConfigured(analytics: analytics, link: link);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            usesAppleAppStoreTipPolicy
                ? context.l10n.monetizationTipsSettingsSaved
                : context.l10n.monetizationSettingsSaved,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _errorTextFor(MonetizationLinkInputInvalidReason reason) {
    return switch (reason) {
      MonetizationLinkInputInvalidReason.empty =>
        context.l10n.monetizationSettingsErrorEmpty,
      MonetizationLinkInputInvalidReason.invalidFormat =>
        context.l10n.monetizationSettingsErrorInvalid,
      MonetizationLinkInputInvalidReason.wrongProvider =>
        context.l10n.monetizationSettingsErrorWrongProvider,
    };
  }
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({
    required this.profile,
    required this.appStoreTipPolicy,
  });

  final UserProfile? profile;
  final bool appStoreTipPolicy;

  @override
  Widget build(BuildContext context) {
    final configured = monetizationLinksForCurrentStorefront(
      profile?.enabledMonetizationLinks ?? const [],
    ).length;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VineTheme.outlineMuted),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(
              appStoreTipPolicy
                  ? context.l10n.monetizationTipsSettingsIntroTitle
                  : context.l10n.monetizationSettingsIntroTitle,
              style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
            ),
            Text(
              appStoreTipPolicy
                  ? context.l10n.monetizationTipsSettingsIntroBody
                  : context.l10n.monetizationSettingsIntroBody,
              style: VineTheme.bodyMediumFont(
                color: VineTheme.onSurfaceVariant,
              ),
            ),
            Text(
              appStoreTipPolicy
                  ? context.l10n.monetizationTipsSettingsConfiguredCount(
                      configured,
                    )
                  : context.l10n.monetizationSettingsConfiguredCount(
                      configured,
                    ),
              style: VineTheme.bodySmallFont(color: VineTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        title.toUpperCase(),
        style: VineTheme.labelSmallFont(color: VineTheme.onSurfaceVariant),
      ),
    );
  }
}

class _ProviderEditor extends StatelessWidget {
  const _ProviderEditor({
    required this.provider,
    required this.controller,
    required this.enabled,
    required this.onEnabledChanged,
    required this.onChanged,
    this.errorText,
  });

  final MonetizationLinkProvider provider;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: VineTheme.outlineMuted),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      provider.displayName,
                      style: VineTheme.titleMediumFont(
                        color: VineTheme.onSurface,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: enabled,
                    onChanged: onEnabledChanged,
                    activeThumbColor: VineTheme.primary,
                  ),
                ],
              ),
              DivineAuthTextField(
                label: _hintForProvider(context, provider),
                controller: controller,
                enabled: enabled,
                autocorrect: false,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                errorText: errorText,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _hintForProvider(
    BuildContext context,
    MonetizationLinkProvider provider,
  ) {
    return switch (provider) {
      MonetizationLinkProvider.cashApp =>
        context.l10n.monetizationSettingsHintCashApp,
      MonetizationLinkProvider.paypal =>
        context.l10n.monetizationSettingsHintPayPal,
      MonetizationLinkProvider.venmo =>
        context.l10n.monetizationSettingsHintVenmo,
      MonetizationLinkProvider.patreon =>
        context.l10n.monetizationSettingsHintPatreon,
      MonetizationLinkProvider.substack =>
        context.l10n.monetizationSettingsHintSubstack,
      MonetizationLinkProvider.medium =>
        context.l10n.monetizationSettingsHintMedium,
      MonetizationLinkProvider.openCollective =>
        context.l10n.monetizationSettingsHintOpenCollective,
    };
  }
}
