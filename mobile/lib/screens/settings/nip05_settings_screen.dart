// ABOUTME: Nostr Settings sub-screen for editing the user's NIP-05 identity.
// ABOUTME: Keeps custom NIP-05 management out of Edit Profile while reusing the
// ABOUTME: existing profile save and username-claim flow.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/profile_editor/username_status_indicator.dart';

const _divineVideoDomainSuffix = '.divine.video';

class Nip05SettingsScreen extends ConsumerWidget {
  static const routeName = 'nip05-settings';
  static const subpath = 'nip05';
  static const path = '/nostr-settings/$subpath';

  const Nip05SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileRepository = ref.watch(profileRepositoryProvider);
    final blossomUploadService = ref.watch(blossomUploadServiceProvider);
    final authService = ref.watch(authServiceProvider);
    final pubkey = authService.currentPublicKeyHex;

    if (profileRepository == null || pubkey == null) {
      return const _Nip05SettingsLoadingScreen();
    }

    return MultiBlocProvider(
      key: ValueKey((profileRepository, blossomUploadService, pubkey)),
      providers: [
        BlocProvider<ProfileEditorBloc>(
          create: (_) => ProfileEditorBloc(
            profileRepository: profileRepository,
            blossomUploadService: blossomUploadService,
            hasExistingProfile: authService.hasExistingProfile,
            currentUserPubkey: pubkey,
          ),
        ),
        BlocProvider<MyProfileBloc>(
          create: (_) => MyProfileBloc(
            profileRepository: profileRepository,
            pubkey: pubkey,
          )..add(const MyProfileLoadRequested()),
        ),
      ],
      child: const Nip05SettingsView(),
    );
  }
}

class _Nip05SettingsLoadingScreen extends StatelessWidget {
  const _Nip05SettingsLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.nostrSettingsNip05Address,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: const Center(
        child: BrandedLoadingIndicator(size: 60),
      ),
    );
  }
}

@visibleForTesting
class Nip05SettingsView extends StatefulWidget {
  const Nip05SettingsView({super.key});

  @override
  State<Nip05SettingsView> createState() => _Nip05SettingsViewState();
}

class _Nip05SettingsViewState extends State<Nip05SettingsView> {
  final _usernameController = TextEditingController();
  final _externalController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _externalFocusNode = FocusNode();
  bool _didSeedInitialValues = false;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onFieldChanged);
    _externalController.addListener(_onFieldChanged);
    _usernameFocusNode.addListener(_onFieldChanged);
    _externalFocusNode.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _usernameController
      ..removeListener(_onFieldChanged)
      ..dispose();
    _externalController
      ..removeListener(_onFieldChanged)
      ..dispose();
    _usernameFocusNode
      ..removeListener(_onFieldChanged)
      ..dispose();
    _externalFocusNode
      ..removeListener(_onFieldChanged)
      ..dispose();
    super.dispose();
  }

  void _onFieldChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.nostrSettingsNip05Address,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: MultiBlocListener(
        listeners: [
          BlocListener<MyProfileBloc, MyProfileState>(
            listenWhen: (previous, current) =>
                !_didSeedInitialValues && _profileFromState(current) != null,
            listener: _seedInitialValues,
          ),
          BlocListener<ProfileEditorBloc, ProfileEditorState>(
            listenWhen: (previous, current) =>
                previous.status != current.status,
            listener: _onSaveStatusChanged,
          ),
        ],
        child: BlocBuilder<MyProfileBloc, MyProfileState>(
          builder: (context, myProfileState) {
            final currentProfile = _profileFromState(myProfileState);
            return BlocBuilder<ProfileEditorBloc, ProfileEditorState>(
              builder: (context, editorState) {
                if (myProfileState is MyProfileError) {
                  return const _Nip05SettingsLoadError();
                }

                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: currentProfile == null
                        ? const Center(child: BrandedLoadingIndicator(size: 60))
                        : ListView(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            children: [
                              _buildIntro(context),
                              const SizedBox(height: 8),
                              _buildDivineUsernameField(context, editorState),
                              const SizedBox(height: 16),
                              _buildToggleRow(context, editorState),
                              if (editorState.nip05Mode == Nip05Mode.external_)
                                _buildExternalNip05Field(context, editorState),
                              const SizedBox(height: 24),
                              _buildSaveButton(
                                context,
                                currentProfile,
                                editorState,
                              ),
                            ],
                          ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        context.l10n.nostrSettingsNip05AddressSubtitle,
        style: VineTheme.bodyMediumFont(color: VineTheme.lightText),
      ),
    );
  }

  Widget _buildDivineUsernameField(
    BuildContext context,
    ProfileEditorState state,
  ) {
    final isExternal = state.nip05Mode == Nip05Mode.external_;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.profileSetupUsernameLabel,
            style: VineTheme.labelMediumFont(
              color: _usernameFocusNode.hasFocus && !isExternal
                  ? VineTheme.primary
                  : VineTheme.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: _usernameController,
            focusNode: _usernameFocusNode,
            enabled: !isExternal,
            style: VineTheme.bodyLargeFont(
              color: isExternal
                  ? VineTheme.onSurfaceMuted
                  : VineTheme.onSurface,
            ),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              isCollapsed: true,
              hintText: context.l10n.profileSetupUsernameHint,
              helperText: context.l10n.profileSetupUsernameHelper,
              helperStyle: const TextStyle(
                color: VineTheme.onSurfaceMuted,
                fontSize: 12,
              ),
              hintStyle: const TextStyle(color: VineTheme.onSurfaceMuted),
              border: const UnderlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: VineTheme.neutral10),
              ),
              enabledBorder: const UnderlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: VineTheme.neutral10),
              ),
              disabledBorder: const UnderlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: VineTheme.neutral10),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: VineTheme.neutral10),
              ),
              errorBorder: const UnderlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: VineTheme.neutral10),
              ),
              focusedErrorBorder: const UnderlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: VineTheme.neutral10),
              ),
              contentPadding: const EdgeInsets.all(16),
              prefixText: '@',
              prefixStyle: VineTheme.bodyLargeFont(
                color: VineTheme.onSurfaceMuted,
              ),
              suffixText: _divineVideoDomainSuffix,
              suffixStyle: VineTheme.bodyLargeFont(
                color: VineTheme.onSurfaceMuted,
              ),
              errorMaxLines: 2,
            ),
            inputFormatters: [
              const LowercaseTextInputFormatter(),
              FilteringTextInputFormatter.allow(RegExp('[a-z0-9-]')),
            ],
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
            onChanged: (value) {
              context.read<ProfileEditorBloc>().add(UsernameChanged(value));
            },
          ),
          if (!isExternal)
            UsernameStatusIndicator(
              status: state.usernameStatus,
              error: state.usernameError,
              formatMessage: state.usernameFormatMessage,
            ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(BuildContext context, ProfileEditorState state) {
    final isExternal = state.nip05Mode == Nip05Mode.external_;
    return GestureDetector(
      onTap: () => _onTogglePressed(context, state),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              isExternal ? Icons.check_box : Icons.check_box_outline_blank,
              color: isExternal
                  ? VineTheme.vineGreen
                  : VineTheme.onSurfaceMuted,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.profileSetupUseOwnNip05,
                style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExternalNip05Field(
    BuildContext context,
    ProfileEditorState state,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            context.l10n.profileSetupNip05AddressLabel,
            style: VineTheme.labelMediumFont(
              color: _externalFocusNode.hasFocus
                  ? VineTheme.primary
                  : VineTheme.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: _externalController,
            focusNode: _externalFocusNode,
            style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
            decoration: InputDecoration(
              isCollapsed: true,
              hintText: context.l10n.nostrSettingsNip05AddressHint,
              hintStyle: const TextStyle(color: VineTheme.onSurfaceMuted),
              border: const UnderlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: VineTheme.neutral10),
              ),
              enabledBorder: const UnderlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: VineTheme.neutral10),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: VineTheme.neutral10),
              ),
              errorBorder: const UnderlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: VineTheme.neutral10),
              ),
              focusedErrorBorder: const UnderlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: VineTheme.neutral10),
              ),
              contentPadding: const EdgeInsets.all(16),
              errorMaxLines: 2,
              errorText: switch (state.externalNip05Error) {
                ExternalNip05ValidationError.invalidFormat =>
                  context.l10n.profileSetupExternalNip05InvalidFormat,
                ExternalNip05ValidationError.divineDomain =>
                  context.l10n.profileSetupExternalNip05DivineDomain,
                null => null,
              },
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              context.read<ProfileEditorBloc>().add(
                ExternalNip05Changed(value),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(
    BuildContext context,
    UserProfile currentProfile,
    ProfileEditorState editorState,
  ) {
    final isLoading = editorState.status == ProfileEditorStatus.loading;
    final canSave =
        !isLoading && editorState.isSaveReady && _isDirty(editorState);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DivineButton(
        label: context.l10n.nostrSettingsNip05SaveAction,
        onPressed: canSave
            ? () => _onSavePressed(context, currentProfile)
            : null,
        expanded: true,
        isLoading: isLoading,
      ),
    );
  }

  void _seedInitialValues(BuildContext context, MyProfileState state) {
    final profile = _profileFromState(state);
    if (profile == null || _didSeedInitialValues) return;

    final extractedUsername = _extractedUsernameFromState(state);
    final externalNip05 = _externalNip05FromState(state);

    if (extractedUsername != null) {
      _usernameController.text = extractedUsername;
    }
    if (externalNip05 != null) {
      _externalController.text = externalNip05;
    }

    final editorBloc = context.read<ProfileEditorBloc>();
    if (extractedUsername != null) {
      editorBloc.add(InitialUsernameSet(extractedUsername));
    }
    if (externalNip05 != null) {
      editorBloc
        ..add(InitialExternalNip05Set(externalNip05))
        ..add(const Nip05ModeChanged(Nip05Mode.external_))
        ..add(ExternalNip05Changed(externalNip05));
    }

    _didSeedInitialValues = true;
  }

  void _onSaveStatusChanged(
    BuildContext context,
    ProfileEditorState state,
  ) {
    if (state.status == ProfileEditorStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.nostrSettingsNip05Saved),
          backgroundColor: VineTheme.vineGreen,
        ),
      );
      context.pop();
      return;
    }

    if (state.status == ProfileEditorStatus.failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.nostrSettingsNip05SaveFailed),
          backgroundColor: VineTheme.error,
        ),
      );
    }
  }

  Future<void> _onTogglePressed(
    BuildContext context,
    ProfileEditorState state,
  ) async {
    final bloc = context.read<ProfileEditorBloc>();
    if (state.nip05Mode == Nip05Mode.external_) {
      bloc
        ..add(const Nip05ModeChanged(Nip05Mode.divine))
        ..add(const ExternalNip05Changed(''));
      return;
    }

    final confirmed = await _showConfirmDialog(context);
    if (!confirmed || !context.mounted) return;
    bloc
      ..add(const Nip05ModeChanged(Nip05Mode.external_))
      ..add(ExternalNip05Changed(_externalController.text));
  }

  Future<bool> _showConfirmDialog(BuildContext context) async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VineTheme.surfaceBackground,
        title: Text(
          l10n.profileSetupNip05ConfirmTitle,
          style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
        ),
        content: Text(
          l10n.profileSetupNip05ConfirmBody,
          style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.profileSetupNip05ConfirmCancel,
              style: VineTheme.labelLargeFont(
                color: VineTheme.onSurfaceMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.profileSetupNip05ConfirmContinue,
              style: VineTheme.labelLargeFont(color: VineTheme.primary),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _onSavePressed(
    BuildContext context,
    UserProfile currentProfile,
  ) {
    context.read<ProfileEditorBloc>().add(
      ProfileNip05Saved(currentProfile: currentProfile),
    );
  }

  bool _isDirty(ProfileEditorState editorState) {
    final normalizedUsername = _usernameController.text.trim().toLowerCase();
    final initialUsername = editorState.initialUsername?.toLowerCase() ?? '';
    final normalizedExternal = _externalController.text.trim().toLowerCase();
    final initialExternal =
        editorState.initialExternalNip05?.trim().toLowerCase() ?? '';

    return switch (editorState.nip05Mode) {
      Nip05Mode.divine =>
        normalizedUsername != initialUsername ||
            editorState.initialExternalNip05 != null,
      Nip05Mode.external_ =>
        normalizedExternal != initialExternal ||
            editorState.initialUsername != null,
    };
  }
}

class _Nip05SettingsLoadError extends StatelessWidget {
  const _Nip05SettingsLoadError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16,
          children: [
            const DivineIcon(
              icon: DivineIconName.warningCircle,
              color: VineTheme.secondaryText,
              size: 48,
            ),
            Text(
              context.l10n.profilePleaseTryAgain,
              textAlign: TextAlign.center,
              style: VineTheme.titleSmallFont(),
            ),
            DivineButton(
              type: DivineButtonType.secondary,
              size: DivineButtonSize.small,
              label: context.l10n.profileRetryButton,
              onPressed: () {
                context.read<MyProfileBloc>().add(
                  const MyProfileLoadRequested(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

UserProfile? _profileFromState(MyProfileState state) {
  return switch (state) {
    MyProfileLoading(:final profile) => profile,
    MyProfileLoaded(:final profile) => profile,
    MyProfileUpdated(:final profile) => profile,
    _ => null,
  };
}

String? _extractedUsernameFromState(MyProfileState state) {
  return switch (state) {
    MyProfileLoading(:final extractedUsername) => extractedUsername,
    MyProfileLoaded(:final extractedUsername) => extractedUsername,
    MyProfileUpdated(:final extractedUsername) => extractedUsername,
    _ => null,
  };
}

String? _externalNip05FromState(MyProfileState state) {
  return switch (state) {
    MyProfileLoading(:final externalNip05) => externalNip05,
    MyProfileLoaded(:final externalNip05) => externalNip05,
    MyProfileUpdated(:final externalNip05) => externalNip05,
    _ => null,
  };
}
