// ABOUTME: Safety Settings screen - navigation hub for moderation and user safety
// ABOUTME: Provides age verification gate and navigation to sub-screens

import 'package:cached_network_image/cached_network_image.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/image_cache_manager.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';

class SafetySettingsScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'safety-settings';

  /// Path for this route.
  static const path = '/safety-settings';

  const SafetySettingsScreen({super.key});

  @override
  ConsumerState<SafetySettingsScreen> createState() =>
      _SafetySettingsScreenState();
}

class _SafetySettingsScreenState extends ConsumerState<SafetySettingsScreen> {
  bool _isLoading = true;
  bool _isAgeVerified = false;
  bool _isDivineLabelerEnabled = true;
  bool _isPeopleIFollowEnabled = false;
  bool _showDivineHostedOnly = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final service = ref.read(ageVerificationServiceProvider);
    await service.initialize();
    final labelService = ref.read(moderationLabelServiceProvider);
    final divineHostFilterService = ref.read(divineHostFilterServiceProvider);
    if (mounted) {
      setState(() {
        _isAgeVerified = service.isAdultContentVerified;
        _isDivineLabelerEnabled = labelService.isDivineLabelerSubscribed;
        _isPeopleIFollowEnabled = labelService.isFollowingModerationEnabled;
        _showDivineHostedOnly = divineHostFilterService.showDivineHostedOnly;
        _isLoading = false;
      });
    }
  }

  Future<void> _setAgeVerified(bool value) async {
    final service = ref.read(ageVerificationServiceProvider);
    await service.setAdultContentVerified(value);

    // If unchecked, lock adult categories to hide
    if (!value) {
      final contentFilterService = ref.read(contentFilterServiceProvider);
      await contentFilterService.lockAdultCategories();
      final videoEventService = ref.read(videoEventServiceProvider);
      videoEventService.filterAdultContentFromExistingVideos();
    }

    if (mounted) {
      setState(() {
        _isAgeVerified = value;
      });
    }
  }

  Future<void> _setShowDivineHostedOnly(bool value) async {
    final service = ref.read(divineHostFilterServiceProvider);
    await service.setShowDivineHostedOnly(value);

    if (mounted) {
      setState(() {
        _showDivineHostedOnly = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: 'Safety & Privacy',
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            )
          : ListView(
              children: [
                _buildAgeVerificationSection(),
                const SizedBox(height: 8),
                _buildSectionHeader('SETTINGS'),
                SwitchListTile(
                  value: _showDivineHostedOnly,
                  onChanged: _setShowDivineHostedOnly,
                  secondary: const Icon(
                    Icons.verified,
                    color: VineTheme.vineGreen,
                  ),
                  title: const Text(
                    'Only show Divine-hosted videos',
                    style: TextStyle(color: VineTheme.whiteText),
                  ),
                  subtitle: const Text(
                    'Hide videos served from other media hosts',
                    style: TextStyle(color: VineTheme.secondaryText),
                  ),
                  activeThumbColor: VineTheme.vineGreen,
                ),
                _buildSectionHeader('MODERATION'),
                _buildModerationProvidersSection(),
                _buildSectionHeader('BLOCKED USERS'),
                _buildBlockedUsersSection(),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
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

  Widget _buildAgeVerificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('AGE VERIFICATION'),
        CheckboxListTile(
          value: _isAgeVerified,
          onChanged: (value) {
            if (value != null) {
              _setAgeVerified(value);
            }
          },
          title: const Text(
            'I confirm I am 18 years or older',
            style: TextStyle(color: VineTheme.whiteText),
          ),
          subtitle: const Text(
            'Required to view adult content',
            style: TextStyle(color: VineTheme.secondaryText),
          ),
          activeColor: VineTheme.vineGreen,
          checkColor: VineTheme.backgroundColor,
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  Widget _buildModerationProvidersSection() {
    return Column(
      children: [
        _buildDivineProvider(),
        _buildPeopleIFollowProvider(),
        _buildCustomLabelersSection(),
      ],
    );
  }

  Widget _buildDivineProvider() {
    return SwitchListTile(
      value: _isDivineLabelerEnabled,
      onChanged: (value) async {
        final labelService = ref.read(moderationLabelServiceProvider);
        if (value) {
          await labelService.addDivineLabeler();
        } else {
          await labelService.removeDivineLabeler();
        }
        setState(() {
          _isDivineLabelerEnabled = value;
        });
      },
      secondary: const Icon(Icons.verified_user, color: VineTheme.vineGreen),
      title: const Text('Divine', style: TextStyle(color: VineTheme.whiteText)),
      subtitle: const Text(
        'Official moderation service (on by default)',
        style: TextStyle(color: VineTheme.secondaryText),
      ),
      activeThumbColor: VineTheme.vineGreen,
    );
  }

  Widget _buildPeopleIFollowProvider() {
    return SwitchListTile(
      value: _isPeopleIFollowEnabled,
      onChanged: (value) async {
        final labelService = ref.read(moderationLabelServiceProvider);
        final followRepository = ref.read(followRepositoryProvider);
        await labelService.setFollowingModerationEnabled(
          value,
          followedPubkeys: followRepository.followingPubkeys,
        );
        if (!mounted) return;
        setState(() {
          _isPeopleIFollowEnabled = value;
        });
      },
      title: const Text(
        'People I follow',
        style: TextStyle(color: VineTheme.whiteText),
      ),
      subtitle: const Text(
        'Subscribe to labels from people you follow',
        style: TextStyle(color: VineTheme.secondaryText),
      ),
      activeThumbColor: VineTheme.vineGreen,
      secondary: Icon(
        Icons.people,
        color: _isPeopleIFollowEnabled
            ? VineTheme.vineGreen
            : VineTheme.onSurfaceDisabled,
      ),
    );
  }

  Future<void> _showAddLabelerDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Add Custom Labeler',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: VineTheme.whiteText),
          decoration: const InputDecoration(
            hintText: 'Enter npub...',
            hintStyle: TextStyle(color: VineTheme.secondaryText),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: VineTheme.secondaryText),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: VineTheme.vineGreen),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text(
              'Add',
              style: TextStyle(color: VineTheme.vineGreen),
            ),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result != null && result.isNotEmpty && mounted) {
      final hexPubkey = npubToHexOrNull(result) ?? result;
      final labelService = ref.read(moderationLabelServiceProvider);
      await labelService.addLabeler(hexPubkey);
      setState(() {});
    }
  }

  Widget _buildCustomLabelersSection() {
    final labelService = ref.read(moderationLabelServiceProvider);
    final customLabelers = labelService.customLabelers.toList();

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
              onPressed: () async {
                await labelService.removeLabeler(pubkey);
                setState(() {});
              },
            ),
          ),
        ),
        ListTile(
          leading: const Icon(
            Icons.add_circle_outline,
            color: VineTheme.onSurfaceDisabled,
          ),
          title: const Text(
            'Add custom labeler',
            style: TextStyle(color: VineTheme.whiteText),
          ),
          subtitle: const Text(
            'Enter npub address',
            style: TextStyle(color: VineTheme.secondaryText),
          ),
          onTap: _showAddLabelerDialog,
        ),
      ],
    );
  }

  Widget _buildBlockedUsersSection() {
    ref.watch(blocklistVersionProvider);

    final blocklistService = ref.read(contentBlocklistServiceProvider);
    final blockedUsers = blocklistService.runtimeBlockedUsers.toList();

    if (blockedUsers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'No blocked users',
          style: TextStyle(
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
              onUnblock: () => _unblockUser(pubkey),
            ),
          )
          .toList(),
    );
  }

  Future<void> _unblockUser(String pubkey) async {
    final blocklistService = ref.read(contentBlocklistServiceProvider);
    blocklistService.unblockUser(pubkey);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User unblocked'),
          duration: Duration(seconds: 2),
        ),
      );
    }
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
              ? CachedNetworkImage(
                  imageUrl: profile.picture!,
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                  cacheManager: openVineImageCache,
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
        child: const Text(
          'Unblock',
          style: TextStyle(color: VineTheme.vineGreen),
        ),
      ),
    );
  }
}
