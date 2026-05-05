// ABOUTME: Nostr Settings → NIP-05 sub-screen for editing the user's NIP-05 identifier.
// ABOUTME: Lets the user toggle between the divine.video username and a custom external NIP-05.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/user_profile_utils.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';

class Nip05SettingsScreen extends ConsumerWidget {
  static const routeName = 'nip05-settings';
  static const path = '/nostr-settings/nip05';

  const Nip05SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileRepository = ref.watch(profileRepositoryProvider);
    final authService = ref.watch(authServiceProvider);
    final pubkey = authService.currentPublicKeyHex;

    if (profileRepository == null || pubkey == null) {
      return const BrandedLoadingScaffold();
    }

    return MultiBlocProvider(
      key: ValueKey((profileRepository, pubkey)),
      providers: [
        BlocProvider<ProfileEditorBloc>(
          create: (_) => ProfileEditorBloc(
            profileRepository: profileRepository,
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
      child: Nip05SettingsView(pubkey: pubkey),
    );
  }
}

@visibleForTesting
class Nip05SettingsView extends StatefulWidget {
  @visibleForTesting
  const Nip05SettingsView({required this.pubkey, super.key});

  final String pubkey;

  @override
  State<Nip05SettingsView> createState() => _Nip05SettingsViewState();
}

class _Nip05SettingsViewState extends State<Nip05SettingsView> {
  final _externalController = TextEditingController();
  final _externalFocus = FocusNode();

  String _displayName = '';
  String? _about;
  String? _picture;
  String? _banner;
  String? _username;
  bool _profileLoaded = false;

  @override
  void initState() {
    super.initState();
    _externalFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    _externalFocus
      ..removeListener(_onFocusChange)
      ..dispose();
    _externalController.dispose();
    super.dispose();
  }

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
            listenWhen: (prev, curr) => curr is MyProfileLoaded,
            listener: _onProfileLoaded,
          ),
          BlocListener<ProfileEditorBloc, ProfileEditorState>(
            listenWhen: (prev, curr) => prev.status != curr.status,
            listener: _onSaveStatusChanged,
          ),
        ],
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: const [
                _Intro(),
                SizedBox(height: 8),
                _ToggleRow(),
                _ExternalNip05Field(),
                SizedBox(height: 24),
                _SaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onProfileLoaded(BuildContext context, MyProfileState state) {
    if (state is! MyProfileLoaded) return;
    final profile = state.profile;
    final externalNip05 = state.externalNip05;
    final extractedUsername = state.extractedUsername;

    setState(() {
      _displayName = profile.displayName ?? profile.name ?? '';
      _about = profile.about;
      _picture = profile.picture;
      final color = profile.profileBackgroundColor;
      _banner = color != null
          ? '0x${color.toARGB32().toRadixString(16).substring(2)}'
          : null;
      _username = extractedUsername;
      if (externalNip05 != null) {
        _externalController.text = externalNip05;
      }
      _profileLoaded = true;
    });

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
  }

  void _onSaveStatusChanged(BuildContext context, ProfileEditorState state) {
    if (state.status == ProfileEditorStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.nostrSettingsNip05Saved),
          backgroundColor: VineTheme.vineGreen,
        ),
      );
      context.pop();
    } else if (state.status == ProfileEditorStatus.failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.nostrSettingsNip05SaveFailed),
          backgroundColor: VineTheme.error,
        ),
      );
    }
  }

  Future<void> _onTogglePressed() async {
    final bloc = context.read<ProfileEditorBloc>();
    final isExternal = bloc.state.nip05Mode == Nip05Mode.external_;
    if (isExternal) {
      bloc
        ..add(const Nip05ModeChanged(Nip05Mode.divine))
        ..add(const ExternalNip05Changed(''));
      return;
    }
    final confirmed = await _showConfirmDialog();
    if (!confirmed || !mounted) return;
    bloc
      ..add(const Nip05ModeChanged(Nip05Mode.external_))
      ..add(ExternalNip05Changed(_externalController.text));
  }

  Future<bool> _showConfirmDialog() async {
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

  void _onSavePressed() {
    if (!_profileLoaded || _displayName.isEmpty) return;
    final bloc = context.read<ProfileEditorBloc>();
    final isExternal = bloc.state.nip05Mode == Nip05Mode.external_;
    bloc.add(
      ProfileSaved(
        pubkey: widget.pubkey,
        displayName: _displayName,
        about: _about,
        username: isExternal ? null : _username,
        externalNip05: isExternal ? _externalController.text : null,
        picture: _picture,
        banner: _banner,
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        context.l10n.nostrSettingsNip05AddressSubtitle,
        style: VineTheme.bodyMediumFont(color: VineTheme.lightText),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileEditorBloc, ProfileEditorState>(
      buildWhen: (prev, curr) => prev.nip05Mode != curr.nip05Mode,
      builder: (context, editorState) {
        final isExternal = editorState.nip05Mode == Nip05Mode.external_;
        final viewState = context
            .findAncestorStateOfType<_Nip05SettingsViewState>();
        return GestureDetector(
          onTap: viewState?._onTogglePressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
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
                    style: VineTheme.bodyLargeFont(
                      color: VineTheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ExternalNip05Field extends StatelessWidget {
  const _ExternalNip05Field();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileEditorBloc, ProfileEditorState>(
      buildWhen: (prev, curr) =>
          prev.nip05Mode != curr.nip05Mode ||
          prev.externalNip05Error != curr.externalNip05Error,
      builder: (context, state) {
        if (state.nip05Mode != Nip05Mode.external_) {
          return const SizedBox.shrink();
        }
        final viewState = context
            .findAncestorStateOfType<_Nip05SettingsViewState>();
        if (viewState == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                context.l10n.profileSetupNip05AddressLabel,
                style: VineTheme.labelMediumFont(
                  color: viewState._externalFocus.hasFocus
                      ? VineTheme.primary
                      : VineTheme.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: viewState._externalController,
                focusNode: viewState._externalFocus,
                style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
                decoration: InputDecoration(
                  isCollapsed: true,
                  hintText: 'you@example.com',
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
                onChanged: (value) => context.read<ProfileEditorBloc>().add(
                  ExternalNip05Changed(value),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileEditorBloc, ProfileEditorState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.nip05Mode != curr.nip05Mode ||
          prev.externalNip05Error != curr.externalNip05Error ||
          prev.externalNip05 != curr.externalNip05,
      builder: (context, state) {
        final viewState = context
            .findAncestorStateOfType<_Nip05SettingsViewState>();
        final isLoading = state.status == ProfileEditorStatus.loading;
        final isExternal = state.nip05Mode == Nip05Mode.external_;
        final canSave =
            !isLoading &&
            (viewState?._profileLoaded ?? false) &&
            (!isExternal || state.isExternalNip05SaveReady);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DivineButton(
            label: context.l10n.nostrSettingsNip05SaveAction,
            onPressed: canSave ? viewState?._onSavePressed : null,
            expanded: true,
            isLoading: isLoading,
          ),
        );
      },
    );
  }
}
