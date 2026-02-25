// ABOUTME: Safety Settings screen - navigation hub for moderation and user safety
// ABOUTME: Provides age verification gate and navigation to sub-screens

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/content_filters_screen.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/image_cache_manager.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:divine_ui/divine_ui.dart';

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
  Set<ContentLabel> _accountLabels = {};
  bool _isDivineLabelerEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final service = ref.read(ageVerificationServiceProvider);
    await service.initialize();
    final accountLabelService = ref.read(accountLabelServiceProvider);
    final labelService = ref.read(moderationLabelServiceProvider);
    if (mounted) {
      setState(() {
        _isAgeVerified = service.isAdultContentVerified;
        _accountLabels = accountLabelService.accountLabels;
        _isDivineLabelerEnabled = labelService.subscribedLabelers.contains(
          ModerationLabelService.divineModerationPubkeyHex,
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        leadingWidth: 80,
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: VineTheme.navGreen,
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: VineTheme.iconButtonBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SvgPicture.asset(
              'assets/icon/CaretLeft.svg',
              width: 32,
              height: 32,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
          onPressed: context.pop,
          tooltip: 'Back',
        ),
        title: Text('Safety & Privacy', style: VineTheme.titleFont()),
      ),
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            )
          : ListView(
              children: [
                _buildAgeVerificationSection(),
                const SizedBox(height: 8),
                _buildSectionHeader('SETTINGS'),
                _buildNavigationTile(
                  icon: Icons.tune,
                  title: 'Content Filters',
                  subtitle: 'Per-category Show, Warn, or Hide',
                  onTap: () => context.push(ContentFiltersScreen.path),
                ),
                _buildNavigationTile(
                  icon: Icons.warning_amber_rounded,
                  title: 'Account Content Labels',
                  subtitle: _accountLabels.isNotEmpty
                      ? _accountLabels.map((l) => l.displayName).join(', ')
                      : 'Self-label your content',
                  onTap: _selectAccountLabels,
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
          checkColor: Colors.black,
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: VineTheme.onSurfaceVariant),
      title: Text(title, style: const TextStyle(color: VineTheme.whiteText)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: VineTheme.secondaryText),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: VineTheme.onSurfaceDisabled,
      ),
      onTap: onTap,
    );
  }

  Future<void> _selectAccountLabels() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final result = await _showAccountLabelMultiSelect(
      context: context,
      selected: _accountLabels,
    );

    if (result != null && mounted) {
      final service = ref.read(accountLabelServiceProvider);
      await service.setAccountLabels(result);
      setState(() {
        _accountLabels = result;
      });
    }
  }

  Future<Set<ContentLabel>?> _showAccountLabelMultiSelect({
    required BuildContext context,
    required Set<ContentLabel> selected,
  }) {
    return showModalBottomSheet<Set<ContentLabel>>(
      context: context,
      backgroundColor: VineTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => _AccountLabelMultiSelect(selected: selected),
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
          await labelService.addLabeler(
            ModerationLabelService.divineModerationPubkeyHex,
          );
        } else {
          await labelService.removeLabeler(
            ModerationLabelService.divineModerationPubkeyHex,
          );
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
      value: false,
      onChanged: (value) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coming soon: Follow-based moderation'),
            duration: Duration(seconds: 2),
          ),
        );
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
      secondary: const Icon(Icons.people, color: VineTheme.onSurfaceDisabled),
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
    final customLabelers = labelService.subscribedLabelers
        .where((pk) => pk != ModerationLabelService.divineModerationPubkeyHex)
        .toList();

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
    ref.read(blocklistVersionProvider.notifier).increment();

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
          border: Border.all(color: VineTheme.onSurfaceDisabled, width: 1),
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

/// Multi-select bottom sheet for choosing account content warning labels.
class _AccountLabelMultiSelect extends StatefulWidget {
  const _AccountLabelMultiSelect({required this.selected});

  final Set<ContentLabel> selected;

  @override
  State<_AccountLabelMultiSelect> createState() =>
      _AccountLabelMultiSelectState();
}

class _AccountLabelMultiSelectState extends State<_AccountLabelMultiSelect> {
  late Set<ContentLabel> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.of(widget.selected);
  }

  void _toggle(ContentLabel label) {
    setState(() {
      if (_selected.contains(label)) {
        _selected.remove(label);
      } else {
        _selected.add(label);
      }
    });
  }

  void _clearAll() {
    setState(() {
      _selected.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: VineTheme.onSurfaceMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Account Content Labels',
                    style: VineTheme.titleFont(
                      fontSize: 18,
                      color: VineTheme.whiteText,
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    TextButton(
                      onPressed: _clearAll,
                      child: const Text(
                        'Clear All',
                        style: TextStyle(color: VineTheme.vineGreen),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Select all that apply to your account',
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: ContentLabel.values.length,
                itemBuilder: (context, index) {
                  final label = ContentLabel.values[index];
                  final isChecked = _selected.contains(label);
                  return CheckboxListTile(
                    value: isChecked,
                    onChanged: (_) => _toggle(label),
                    title: Text(
                      label.displayName,
                      style: const TextStyle(
                        color: VineTheme.whiteText,
                        fontSize: 15,
                      ),
                    ),
                    activeColor: VineTheme.vineGreen,
                    checkColor: VineTheme.whiteText,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VineTheme.vineGreen,
                      foregroundColor: VineTheme.whiteText,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _selected.isEmpty
                          ? 'Done (No Labels)'
                          : 'Done (${_selected.length} selected)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
