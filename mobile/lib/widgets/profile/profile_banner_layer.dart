// ABOUTME: Banner layer rendered edge-to-edge behind the profile content
// ABOUTME: Scroll-driven: moves up as user scrolls, extends behind status bar

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/user_profile_utils.dart';
import 'package:openvine/widgets/profile/profile_header_widget.dart';

/// Renders the profile banner as a separate Stack layer in [ProfileGridView].
///
/// Unlike the rest of the profile content (which lives inside a [SafeArea]
/// and therefore starts below the status bar), this layer is positioned at
/// the screen edge so the banner image/gradient can show through the safe
/// area. The layer listens to the parent scroll controller and translates
/// its top offset upward as the user scrolls, so the banner scrolls away
/// naturally with the rest of the content.
class ProfileBannerLayer extends ConsumerStatefulWidget {
  const ProfileBannerLayer({
    required this.userIdHex,
    required this.isOwnProfile,
    this.profile,
    this.scrollController,
    this.height = 334.0,
    super.key,
  });

  final String userIdHex;
  final bool isOwnProfile;
  final UserProfile? profile;
  final ScrollController? scrollController;
  final double height;

  @override
  ConsumerState<ProfileBannerLayer> createState() => _ProfileBannerLayerState();
}

class _ProfileBannerLayerState extends ConsumerState<ProfileBannerLayer> {
  /// Banner top offset driven by scroll. Always <= 0 when scrolled.
  final _topOffset = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ProfileBannerLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScroll);
      widget.scrollController?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    _topOffset.dispose();
    super.dispose();
  }

  void _onScroll() {
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) return;
    // Clamp so the banner stops moving once it is fully offscreen.
    _topOffset.value = (-controller.offset).clamp(-widget.height, 0.0);
  }

  @override
  Widget build(BuildContext context) {
    // Resolve effective profile (same logic as ProfileHeaderWidget).
    final UserProfile? effectiveProfile;
    if (widget.isOwnProfile) {
      final state = context.watch<MyProfileBloc>().state;
      effectiveProfile = switch (state) {
        MyProfileUpdated(:final profile) => profile,
        _ => null,
      };
    } else if (widget.profile != null) {
      effectiveProfile = widget.profile;
    } else {
      effectiveProfile = ref
          .watch(fetchUserProfileProvider(widget.userIdHex))
          .value;
    }

    final hasBannerImage = effectiveProfile?.hasBannerImage ?? false;
    final bannerUrl = hasBannerImage ? effectiveProfile!.banner : null;
    final profileColor = effectiveProfile?.profileBackgroundColor;

    return ValueListenableBuilder<double>(
      valueListenable: _topOffset,
      builder: (_, topOffset, child) => Positioned(
        top: topOffset,
        left: 0,
        right: 0,
        height: widget.height,
        child: child!,
      ),
      child: ExcludeSemantics(
        child: ProfileBanner(
          bannerUrl: bannerUrl,
          profileColor: profileColor,
          height: widget.height,
        ),
      ),
    );
  }
}
