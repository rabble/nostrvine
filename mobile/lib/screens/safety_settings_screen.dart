// ABOUTME: Safety Settings screen - navigation hub for moderation and user safety
// ABOUTME: Provides age verification gate and navigation to sub-screens

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/safety_settings/safety_settings_cubit.dart';
import 'package:openvine/blocs/safety_settings/safety_settings_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/content_filters_screen.dart';
import 'package:openvine/screens/settings/account_content_labels_tile.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Page: bridges the seven moderation services + repositories into
/// [SafetySettingsCubit].
class SafetySettingsScreen extends ConsumerWidget {
  const SafetySettingsScreen({super.key});

  /// Route name for this screen.
  static const routeName = 'safety-settings';

  /// Path for this route.
  static const path = '/safety-settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ageVerificationService = ref.watch(ageVerificationServiceProvider);
    final contentFilterService = ref.watch(contentFilterServiceProvider);
    final videoEventService = ref.watch(videoEventServiceProvider);
    final divineHostFilterService = ref.watch(divineHostFilterServiceProvider);
    final moderationLabelService = ref.watch(moderationLabelServiceProvider);
    final followRepository = ref.watch(followRepositoryProvider);
    final contentBlocklistRepository = ref.watch(
      contentBlocklistRepositoryProvider,
    );
    final isAdultContentLocked = ref.watch(isProtectedMinorProvider);
    return BlocProvider(
      // Auth-flippable services are re-keyed so the Cubit reloads with the
      // fresh instances rather than operating on stale ones.
      key: ValueKey((
        ageVerificationService,
        contentFilterService,
        videoEventService,
        divineHostFilterService,
        moderationLabelService,
        followRepository,
        contentBlocklistRepository,
        isAdultContentLocked,
      )),
      create: (_) => SafetySettingsCubit(
        ageVerificationService: ageVerificationService,
        contentFilterService: contentFilterService,
        videoEventService: videoEventService,
        divineHostFilterService: divineHostFilterService,
        moderationLabelService: moderationLabelService,
        followRepository: followRepository,
        contentBlocklistRepository: contentBlocklistRepository,
        isAdultContentLocked: isAdultContentLocked,
      )..load(),
      child: const SafetySettingsView(),
    );
  }
}

/// View: renders the moderation hub from the Cubit state.
class SafetySettingsView extends StatelessWidget {
  @visibleForTesting
  const SafetySettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.settingsContentSafetyTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: BlocBuilder<SafetySettingsCubit, SafetySettingsState>(
            builder: (context, state) {
              if (state.status == SafetySettingsStatus.loading) {
                return const Center(
                  child: CircularProgressIndicator(color: VineTheme.vineGreen),
                );
              }
              return ListView(
                children: [
                  _SectionHeader(context.l10n.safetySettingsWhatYouSee),
                  const _ContentFiltersTile(),
                  _SectionHeader(context.l10n.safetySettingsAgeVerification),
                  const _AgeVerificationTile(),
                  const SizedBox(height: 8),
                  const _DivineHostedOnlyTile(),
                  _SectionHeader(context.l10n.safetySettingsModeration),
                  const _DivineProviderTile(),
                  const _PeopleIFollowProviderTile(),
                  const _CustomLabelersSection(),
                  _SectionHeader(context.l10n.safetySettingsBlockedUsers),
                  const _BlockedUsersSection(),
                  _SectionHeader(context.l10n.safetySettingsWhatYouPublish),
                  const AccountContentLabelsTile(),
                ],
              );
            },
          ),
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
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: VineTheme.vineGreen,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ContentFiltersTile extends StatelessWidget {
  const _ContentFiltersTile();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const DivineIcon(
        icon: DivineIconName.funnelSimple,
        color: VineTheme.vineGreen,
      ),
      title: Text(
        context.l10n.contentPreferencesContentFilters,
        style: const TextStyle(color: VineTheme.whiteText),
      ),
      subtitle: Text(
        context.l10n.contentPreferencesContentFiltersSubtitle,
        style: const TextStyle(color: VineTheme.secondaryText),
      ),
      trailing: const DivineIcon(
        icon: DivineIconName.caretRight,
        color: VineTheme.lightText,
      ),
      onTap: () => context.push(ContentFiltersScreen.path),
    );
  }
}

class _AgeVerificationTile extends StatelessWidget {
  const _AgeVerificationTile();

  @override
  Widget build(BuildContext context) {
    final isAgeVerified = context.select(
      (SafetySettingsCubit cubit) => cubit.state.isAgeVerified,
    );
    final isLocked = context.select(
      (SafetySettingsCubit cubit) => cubit.state.isAdultContentLocked,
    );
    return CheckboxListTile(
      value: !isLocked && isAgeVerified,
      onChanged: isLocked
          ? null
          : (value) {
              if (value != null) {
                context.read<SafetySettingsCubit>().setAgeVerified(value);
              }
            },
      title: Text(
        context.l10n.safetySettingsAgeConfirmation,
        style: const TextStyle(color: VineTheme.whiteText),
      ),
      subtitle: Text(
        isLocked
            ? context.l10n.safetySettingsAgeLockedForMinor
            : context.l10n.safetySettingsAgeRequired,
        style: const TextStyle(color: VineTheme.secondaryText),
      ),
      activeColor: VineTheme.vineGreen,
      checkColor: VineTheme.backgroundColor,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}

class _DivineHostedOnlyTile extends StatelessWidget {
  const _DivineHostedOnlyTile();

  @override
  Widget build(BuildContext context) {
    final showDivineHostedOnly = context.select(
      (SafetySettingsCubit cubit) => cubit.state.showDivineHostedOnly,
    );
    return SwitchListTile(
      value: showDivineHostedOnly,
      onChanged: (value) =>
          context.read<SafetySettingsCubit>().setShowDivineHostedOnly(value),
      secondary: const DivineIcon(
        icon: DivineIconName.sealCheck,
        color: VineTheme.vineGreen,
      ),
      title: Text(
        context.l10n.safetySettingsShowDivineHostedOnly,
        style: const TextStyle(color: VineTheme.whiteText),
      ),
      subtitle: Text(
        context.l10n.safetySettingsShowDivineHostedOnlySubtitle,
        style: const TextStyle(color: VineTheme.secondaryText),
      ),
      activeThumbColor: VineTheme.vineGreen,
    );
  }
}

class _DivineProviderTile extends StatelessWidget {
  const _DivineProviderTile();

  @override
  Widget build(BuildContext context) {
    // The built-in Divine moderation labeler is always on by product design.
    return SwitchListTile(
      value: true,
      onChanged: null,
      secondary: const DivineIcon(
        icon: DivineIconName.shieldCheck,
        color: VineTheme.vineGreen,
      ),
      title: Text(
        context.l10n.safetySettingsDivine,
        style: const TextStyle(color: VineTheme.whiteText),
      ),
      subtitle: Text(
        context.l10n.safetySettingsDivineSubtitle,
        style: const TextStyle(color: VineTheme.secondaryText),
      ),
      activeThumbColor: VineTheme.vineGreen,
    );
  }
}

class _PeopleIFollowProviderTile extends StatelessWidget {
  const _PeopleIFollowProviderTile();

  @override
  Widget build(BuildContext context) {
    final isEnabled = context.select(
      (SafetySettingsCubit cubit) => cubit.state.isPeopleIFollowEnabled,
    );
    return SwitchListTile(
      value: isEnabled,
      onChanged: (value) =>
          context.read<SafetySettingsCubit>().setPeopleIFollowEnabled(value),
      title: Text(
        context.l10n.safetySettingsPeopleIFollow,
        style: const TextStyle(color: VineTheme.whiteText),
      ),
      subtitle: Text(
        context.l10n.safetySettingsPeopleIFollowSubtitle,
        style: const TextStyle(color: VineTheme.secondaryText),
      ),
      activeThumbColor: VineTheme.vineGreen,
      secondary: Icon(
        Icons.people,
        color: isEnabled ? VineTheme.vineGreen : VineTheme.onSurfaceDisabled,
      ),
    );
  }
}

class _CustomLabelersSection extends StatelessWidget {
  const _CustomLabelersSection();

  @override
  Widget build(BuildContext context) {
    final customLabelers = context.select(
      (SafetySettingsCubit cubit) => cubit.state.customLabelers,
    );
    return Column(
      children: [
        ...customLabelers.map(
          (pubkey) => ListTile(
            leading: const Icon(
              Icons.label_outline,
              color: VineTheme.onSurfaceDisabled,
            ),
            title: Text(
              NostrKeyUtils.truncateNpub(pubkey),
              style: const TextStyle(color: VineTheme.whiteText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.remove_circle_outline,
                color: VineTheme.secondaryText,
              ),
              onPressed: () =>
                  context.read<SafetySettingsCubit>().removeLabeler(pubkey),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(
            Icons.add_circle_outline,
            color: VineTheme.onSurfaceDisabled,
          ),
          title: Text(
            context.l10n.safetySettingsAddCustomLabelerListTitle,
            style: const TextStyle(color: VineTheme.whiteText),
          ),
          subtitle: Text(
            context.l10n.safetySettingsAddCustomLabelerListSubtitle,
            style: const TextStyle(color: VineTheme.secondaryText),
          ),
          onTap: () => _showAddLabelerDialog(context),
        ),
      ],
    );
  }

  Future<void> _showAddLabelerDialog(BuildContext context) async {
    final cubit = context.read<SafetySettingsCubit>();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _AddLabelerDialog(),
    );
    if (result != null && result.isNotEmpty) {
      await cubit.addLabeler(result);
    }
  }
}

class _AddLabelerDialog extends StatefulWidget {
  const _AddLabelerDialog();

  @override
  State<_AddLabelerDialog> createState() => _AddLabelerDialogState();
}

class _AddLabelerDialogState extends State<_AddLabelerDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: Text(
        context.l10n.safetySettingsAddCustomLabeler,
        style: const TextStyle(color: VineTheme.whiteText),
      ),
      content: TextField(
        controller: _controller,
        style: const TextStyle(color: VineTheme.whiteText),
        decoration: InputDecoration(
          hintText: context.l10n.safetySettingsAddCustomLabelerHint,
          hintStyle: const TextStyle(color: VineTheme.secondaryText),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: VineTheme.secondaryText),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: VineTheme.vineGreen),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            context.l10n.safetySettingsCancel,
            style: const TextStyle(color: VineTheme.secondaryText),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(
            context.l10n.safetySettingsAdd,
            style: const TextStyle(color: VineTheme.vineGreen),
          ),
        ),
      ],
    );
  }
}

class _BlockedUsersSection extends StatelessWidget {
  const _BlockedUsersSection();

  @override
  Widget build(BuildContext context) {
    final blockedUsers = context.select(
      (SafetySettingsCubit cubit) => cubit.state.blockedUsers,
    );
    if (blockedUsers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          context.l10n.safetySettingsNoBlockedUsers,
          style: const TextStyle(
            color: VineTheme.secondaryText,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return Column(
      children: blockedUsers
          .map(
            (pubkey) => _BlockedUserTile(
              pubkey: pubkey,
              onUnblock: () => _unblockUser(context, pubkey),
            ),
          )
          .toList(),
    );
  }

  Future<void> _unblockUser(BuildContext context, String pubkey) async {
    final cubit = context.read<SafetySettingsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    await cubit.unblockUser(pubkey);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.safetySettingsUserUnblocked),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Tile widget for displaying a blocked user with unblock option.
class _BlockedUserTile extends ConsumerWidget {
  const _BlockedUserTile({required this.pubkey, required this.onUnblock});

  final String pubkey;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileReactiveProvider(pubkey));
    final profile = profileAsync.value;
    final truncatedNpub = NostrKeyUtils.truncateNpub(pubkey);
    final displayName = profile?.bestDisplayName ?? truncatedNpub;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VineTheme.onSurfaceDisabled),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: profile?.picture != null && profile!.picture!.isNotEmpty
              ? VineCachedImage(
                  imageUrl: profile.picture!,
                  width: 38,
                  height: 38,
                  placeholder: (context, url) => Image.asset(
                    'assets/icon/acid_avatar.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                  ),
                  errorWidget: (context, url, error) => Image.asset(
                    'assets/icon/acid_avatar.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                  ),
                )
              : Image.asset(
                  'assets/icon/acid_avatar.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                ),
        ),
      ),
      title: Text(
        displayName,
        style: const TextStyle(color: VineTheme.whiteText),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        truncatedNpub,
        style: const TextStyle(color: VineTheme.secondaryText, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: TextButton(
        onPressed: onUnblock,
        child: Text(
          context.l10n.safetySettingsUnblock,
          style: const TextStyle(color: VineTheme.vineGreen),
        ),
      ),
    );
  }
}
