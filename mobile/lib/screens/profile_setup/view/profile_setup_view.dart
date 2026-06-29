import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/profile_setup/widgets/widgets.dart';
import 'package:openvine/widgets/profile/nostr_info_sheet_content.dart';

class ProfileSetupScreenView extends ConsumerStatefulWidget {
  const ProfileSetupScreenView({required this.isNewUser, super.key});
  final bool isNewUser;

  @override
  ConsumerState<ProfileSetupScreenView> createState() =>
      _ProfileSetupScreenViewState();
}

class _ProfileSetupScreenViewState extends ConsumerState<ProfileSetupScreenView>
    with WidgetsBindingObserver {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _websiteController = TextEditingController();
  final _nip05Controller = TextEditingController();
  // Owned here (not in DisplayNameField) so the Save action can focus the
  // name field when it is left empty.
  final _nameFocusNode = FocusNode();
  bool _refreshProfileOnResume = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed || !_refreshProfileOnResume) {
      return;
    }

    _refreshProfileOnResume = false;
    context.read<MyProfileBloc>().add(const MyProfileFetchRequested());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    _nip05Controller.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;

    return ProfileSetupListeners(
      isNewUser: widget.isNewUser,
      nameController: _nameController,
      bioController: _bioController,
      websiteController: _websiteController,
      nip05Controller: _nip05Controller,
      onNativeVerifierLaunched: () => _refreshProfileOnResume = true,
      child: BlocBuilder<ProfileEditorBloc, ProfileEditorState>(
        builder: (context, profileEditorState) {
          return Scaffold(
            backgroundColor: VineTheme.surfaceContainerHigh,
            appBar: DiVineAppBar(
              title: context.l10n.profileSetupEditProfileTitle,
              backgroundMode: DiVineAppBarBackgroundMode.transparent,
              showBackButton: true,
              backButtonSemanticLabel: context.l10n.profileSetupBackLabel,
              onBackPressed: () {
                if (context.canPop()) {
                  context.pop();
                  return;
                }
                final authService = ref.read(authServiceProvider);
                final currentPubkey = authService.currentPublicKeyHex;
                if (currentPubkey != null) {
                  final npub = authService.currentNpub;
                  context.go('/profile/$npub');
                } else {
                  context.go('/home/0');
                }
              },
              style: const DiVineAppBarStyle(
                iconButtonBackgroundColor: VineTheme.scrim15,
              ),
              actions: [
                DiVineAppBarAction(
                  icon: SvgIconSource(DivineIconName.info.assetPath),
                  onPressed: () => _showNostrInfoSheet(context),
                  tooltip: context.l10n.profileSetupAboutNostr,
                  semanticLabel: context.l10n.profileSetupAboutNostr,
                ),
              ],
            ),
            body: GestureDetector(
              onTap: () {
                // Dismiss keyboard when tapping outside text fields
                FocusScope.of(context).unfocus();
              },
              child: SafeArea(
                bottom:
                    false, // Don't add bottom padding - let content extend to bottom
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            textSelectionTheme: const TextSelectionThemeData(
                              cursorColor: VineTheme.primary,
                              selectionColor: Color(0xFF1C4430),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ProfileAvatarSection(
                                nameController: _nameController,
                              ),
                              const SizedBox(height: 24),

                              DisplayNameField(
                                controller: _nameController,
                                focusNode: _nameFocusNode,
                              ),
                              const SizedBox(height: 16),

                              BioField(controller: _bioController),
                              const SizedBox(height: 16),

                              WebsiteField(controller: _websiteController),
                              const SizedBox(height: 16),

                              const VerifiedAccountsSection(),

                              const PublicKeyLink(),
                              const SizedBox(height: 16),

                              UsernameField(controller: _nip05Controller),
                              const SizedBox(height: 24),

                              // Banner section: image upload + color swatches.
                              // Replaces the old standalone profile-color
                              // picker; the bloc serializes the chosen color
                              // into the same kind-0 `banner` field.
                              const BannerEditingBlock(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            profileEditorState.status ==
                                ProfileEditorStatus.loading
                            ? null
                            : () {
                                // Wait for any ongoing transitions before popping
                                // This prevents navigation timing race condition
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted) {
                                    Navigator.of(context).pop();
                                  }
                                });
                              },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: VineTheme.surfaceContainer,
                          foregroundColor: VineTheme.vineGreen,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          side: const BorderSide(
                            color: VineTheme.outlineMuted,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          context.l10n.commonCancel,
                          style: VineTheme.titleMediumFont(
                            color: VineTheme.vineGreen,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (pubkey != null)
                      Expanded(
                        child: SaveButton(
                          canSave: profileEditorState.isSaveReady,
                          onSave: () {
                            if (_nameController.text.trim().isEmpty) {
                              _nameFocusNode.requestFocus();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context
                                        .l10n
                                        .profileSetupDisplayNameRequired,
                                  ),
                                  backgroundColor: VineTheme.error,
                                ),
                              );
                              return;
                            }
                            context.read<ProfileEditorBloc>().add(
                              ProfileSaved(
                                pubkey: pubkey,
                                displayName: _nameController.text,
                                about: _bioController.text,
                                website: _websiteController.text,
                                username: _nip05Controller.text,
                                // Picture and banner are owned by bloc state.
                                // The bloc reads pendingPictureUrl /
                                // pendingBannerUrl / pendingBannerColor /
                                // persistedBanner directly via
                                // `effectiveBanner`, so we don't pass them
                                // through the event.
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showNostrInfoSheet(BuildContext context) {
    // Unfocus any field before opening sheet
    FocusScope.of(context).unfocus();
    VineBottomSheet.show<void>(
      context: context,
      children: const [NostrInfoSheetContent()],
    ).then((_) {
      // Unfocus after sheet is dismissed to prevent auto-focus on form fields
      if (context.mounted) {
        FocusScope.of(context).unfocus();
      }
    });
  }
}
