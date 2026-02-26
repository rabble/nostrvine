// ABOUTME: Welcome screen with returning-user variant and new-user variant
// ABOUTME: Page/View pattern with WelcomeBloc for state management
// DESIGN: https://www.figma.com/design/rp1DsDEUuCaicW0lk6I2aZ/UI-Design?node-id=6562-57240

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/welcome/welcome_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/auth/auth_hero_section.dart';
import 'package:openvine/widgets/divine_primary_button.dart';
import 'package:openvine/widgets/divine_secondary_button.dart';
import 'package:openvine/widgets/error_message.dart';
import 'package:openvine/widgets/rounded_icon_button.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

/// Welcome screen — Page that provides [WelcomeBloc] and auth state.
class WelcomeScreen extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'welcome';

  /// Path for this route.
  static const path = '/welcome';

  /// Path for login options route.
  static const loginOptionsPath = '/welcome/login-options';

  /// Path for create account route.
  static const createAccountPath = '/welcome/create-account';

  /// Path for reset password route.
  static const resetPasswordPath = '/welcome/login-options/reset-password';

  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(currentAuthStateProvider);
    final authService = ref.watch(authServiceProvider);
    final db = ref.watch(databaseProvider);

    final isAuthLoading =
        authState == AuthState.checking ||
        authState == AuthState.authenticating;

    return BlocProvider(
      create: (_) => WelcomeBloc(
        userProfilesDao: db.userProfilesDao,
        authService: authService,
      )..add(const WelcomeStarted()),
      child: _WelcomeView(
        isAuthLoading: isAuthLoading,
        lastError: authService.lastError,
      ),
    );
  }
}

/// Welcome screen — View that consumes [WelcomeBloc] state.
class _WelcomeView extends StatelessWidget {
  const _WelcomeView({required this.isAuthLoading, required this.lastError});

  /// Whether the global auth state is in a loading state.
  final bool isAuthLoading;

  /// Auth service error to display, if any.
  final String? lastError;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WelcomeBloc, WelcomeState>(
      listenWhen: (prev, current) =>
          current.status == WelcomeStatus.navigatingToLoginOptions ||
          current.status == WelcomeStatus.navigatingToCreateAccount ||
          (current.status == WelcomeStatus.error && current.error != null),
      listener: (context, state) {
        switch (state.status) {
          case WelcomeStatus.navigatingToCreateAccount:
            context.push(WelcomeScreen.createAccountPath);
          case WelcomeStatus.navigatingToLoginOptions:
            context.push(WelcomeScreen.loginOptionsPath);
          case WelcomeStatus.error when state.error != null:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: VineTheme.error,
              ),
            );
          default:
            break;
        }
      },
      builder: (context, state) {
        final isLoading = isAuthLoading || state.isAccepting;

        return Scaffold(
          backgroundColor: VineTheme.backgroundColor,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: state.hasReturningUsers
                  ? _ReturningUserLayout(
                      state: state,
                      isLoading: isLoading,
                      lastError: lastError,
                    )
                  : _NewUserLayout(isLoading: isLoading, lastError: lastError),
            ),
          ),
        );
      },
    );
  }
}

/// Default layout for new users — AuthHeroSection with create/login buttons.
class _NewUserLayout extends StatelessWidget {
  const _NewUserLayout({required this.isLoading, required this.lastError});

  final bool isLoading;
  final String? lastError;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(child: Center(child: AuthHeroSection())),

        if (lastError != null) ...[
          ErrorMessage(message: lastError),
          const SizedBox(height: 16),
        ],

        if (!isLoading) ...[
          DivinePrimaryButton(
            label: 'Create a new Divine account',
            onPressed: () => context.read<WelcomeBloc>().add(
              const WelcomeCreateAccountRequested(),
            ),
          ),

          const SizedBox(height: 12),

          DivineSecondaryButton(
            label: 'Sign in with a different account',
            onPressed: () => context.read<WelcomeBloc>().add(
              const WelcomeLoginOptionsRequested(),
            ),
          ),

          const SizedBox(height: 20),
        ],
        const _TermsNotice(),

        const SizedBox(height: 32),
      ],
    );
  }
}

/// Returning-user layout with profile info and log back in button.
class _ReturningUserLayout extends StatelessWidget {
  const _ReturningUserLayout({
    required this.state,
    required this.isLoading,
    required this.lastError,
  });

  final WelcomeState state;
  final bool isLoading;
  final String? lastError;

  void _showAccountPicker(
    BuildContext context, {
    required List<PreviousAccount> accounts,
    required String selectedPubkeyHex,
  }) {
    final bloc = context.read<WelcomeBloc>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VineTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AccountPickerSheet(
        accounts: accounts,
        selectedPubkeyHex: selectedPubkeyHex,
        bloc: bloc,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = state.selectedAccount;
    if (account == null) return const SizedBox.shrink();

    return Column(
      children: [
        // "Welcome back!" title — centered between top and profile
        const Expanded(
          child: Center(
            child: Text(
              'Welcome back!',
              style: TextStyle(
                fontFamily: VineTheme.fontFamilyBricolage,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: VineTheme.whiteText,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        // Profile section
        _ReturningUserProfile(
          pubkeyHex: account.pubkeyHex,
          profile: account.profile,
          onSwitchAccount: state.previousAccounts.length > 1
              ? () => _showAccountPicker(
                  context,
                  accounts: state.previousAccounts,
                  selectedPubkeyHex: account.pubkeyHex,
                )
              : null,
        ),

        const Spacer(),

        if (lastError != null) ...[
          ErrorMessage(message: lastError),
          const SizedBox(height: 16),
        ],

        // Sign back in button (primary)
        DivinePrimaryButton(
          label: 'Sign back in',
          isLoading: isLoading,
          onPressed: () => context.read<WelcomeBloc>().add(
            const WelcomeLogBackInRequested(),
          ),
        ),

        const SizedBox(height: 12),

        // Login with different account (secondary)
        DivineSecondaryButton(
          label: 'Sign in with a different account',
          onPressed: isLoading
              ? null
              : () => context.read<WelcomeBloc>().add(
                  const WelcomeLoginOptionsRequested(),
                ),
        ),

        const SizedBox(height: 12),

        // Create new account (tertiary)
        DivineSecondaryButton(
          label: 'Create a new Divine account',
          onPressed: isLoading
              ? null
              : () => context.read<WelcomeBloc>().add(
                  const WelcomeCreateAccountRequested(),
                ),
        ),

        const SizedBox(height: 20),

        const _TermsNotice(),

        const SizedBox(height: 32),
      ],
    );
  }
}

/// Displays the returning user's avatar, display name, identifier, and auth
/// source badge.
class _ReturningUserProfile extends StatelessWidget {
  const _ReturningUserProfile({
    required this.pubkeyHex,
    required this.profile,
    this.onSwitchAccount,
  });

  final String pubkeyHex;
  final UserProfile? profile;

  /// When non-null, a switch-account icon button is overlaid on the avatar.
  final VoidCallback? onSwitchAccount;

  @override
  Widget build(BuildContext context) {
    final displayName =
        profile?.bestDisplayName ??
        UserProfile.defaultDisplayNameFor(pubkeyHex);

    final identifier =
        profile?.displayNip05 ?? NostrKeyUtils.truncateNpub(pubkeyHex);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AvatarWithSwitchButton(
          imageUrl: profile?.picture,
          displayName: displayName,
          onSwitchAccount: onSwitchAccount,
        ),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: VineTheme.whiteText,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          identifier,
          style: const TextStyle(fontSize: 14, color: VineTheme.vineGreen),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Avatar with an optional switch-account icon button at the bottom center.
class _AvatarWithSwitchButton extends StatelessWidget {
  const _AvatarWithSwitchButton({
    required this.imageUrl,
    required this.displayName,
    this.onSwitchAccount,
  });

  final String? imageUrl;
  final String displayName;
  final VoidCallback? onSwitchAccount;

  static const double _avatarSize = 144;

  @override
  Widget build(BuildContext context) {
    final avatar = UserAvatar(
      imageUrl: imageUrl,
      name: displayName,
      size: _avatarSize,
    );

    if (onSwitchAccount == null) return avatar;

    return SizedBox(
      width: _avatarSize,
      height: _avatarSize + 25,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(child: _SwitchAccountButton(onTap: onSwitchAccount!)),
          ),
        ],
      ),
    );
  }
}

/// Small icon button for switching accounts, overlaid on the avatar.
class _SwitchAccountButton extends StatelessWidget {
  const _SwitchAccountButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RoundedIconButton(
      onPressed: onTap,
      icon: const Icon(Icons.swap_horiz, size: 24, color: VineTheme.vineGreen),
    );
  }
}

/// Bottom sheet listing all known accounts for selection.
// DESIGN: https://www.figma.com/design/rp1DsDEUuCaicW0lk6I2aZ/UI-Design?node-id=7598-15054
class _AccountPickerSheet extends StatelessWidget {
  const _AccountPickerSheet({
    required this.accounts,
    required this.selectedPubkeyHex,
    required this.bloc,
  });

  final List<PreviousAccount> accounts;
  final String selectedPubkeyHex;
  final WelcomeBloc bloc;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: VineTheme.outlineMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Sign in as...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: VineTheme.whiteText,
            ),
          ),
          const SizedBox(height: 16),

          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                return _AccountTile(
                  account: account,
                  isSelected: account.pubkeyHex == selectedPubkeyHex,
                  onTap: () {
                    bloc.add(
                      WelcomeAccountSelected(pubkeyHex: account.pubkeyHex),
                    );
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Single account row in the picker sheet.
class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.isSelected,
    required this.onTap,
  });

  final PreviousAccount account;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName =
        account.profile?.bestDisplayName ??
        UserProfile.defaultDisplayNameFor(account.pubkeyHex);

    final identifier =
        account.profile?.displayNip05 ??
        NostrKeyUtils.truncateNpub(account.pubkeyHex);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? VineTheme.vineGreen.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            UserAvatar(
              imageUrl: account.profile?.picture,
              name: displayName,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: VineTheme.whiteText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    identifier,
                    style: const TextStyle(
                      fontSize: 13,
                      color: VineTheme.secondaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, size: 20, color: VineTheme.vineGreen),
          ],
        ),
      ),
    );
  }
}

/// Passive terms notice text with clickable links.
class _TermsNotice extends StatefulWidget {
  const _TermsNotice();

  @override
  State<_TermsNotice> createState() => _TermsNoticeState();
}

class _TermsNoticeState extends State<_TermsNotice> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;
  late final TapGestureRecognizer _safetyRecognizer;

  Future<void> _openUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl('https://divine.video/terms');
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl('https://divine.video/privacy');
    _safetyRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl('https://divine.video/safety');
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    _safetyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const linkStyle = TextStyle(
      color: VineTheme.whiteText,
      decoration: TextDecoration.underline,
      decorationColor: VineTheme.vineGreen,
    );

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          color: VineTheme.secondaryText,
          height: 1.4,
        ),
        children: [
          const TextSpan(
            text:
                'By selecting an option above, you confirm you are '
                'at least 16 years old and agree to the ',
          ),
          TextSpan(
            text: 'Terms of Service',
            style: linkStyle,
            recognizer: _termsRecognizer,
          ),
          const TextSpan(text: ', '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: _privacyRecognizer,
          ),
          const TextSpan(text: ', and '),
          TextSpan(
            text: 'Safety Standards',
            style: linkStyle,
            recognizer: _safetyRecognizer,
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}
