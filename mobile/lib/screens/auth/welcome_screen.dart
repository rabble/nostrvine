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
import 'package:openvine/widgets/error_message.dart';
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

  /// Path for invite gate route.
  static const inviteGatePath = '/welcome/invite';

  /// Path for reset password route.
  static const resetPasswordPath = '/welcome/login-options/reset-password';

  /// Query parameter key for pre-selecting an account on the welcome screen.
  static const selectedPubkeyParam = 'selectedPubkey';

  /// Build a welcome path with a pre-selected account pubkey.
  static String pathWithSelectedPubkey(String pubkeyHex) => Uri(
    path: path,
    queryParameters: {selectedPubkeyParam: pubkeyHex},
  ).toString();

  /// Build invite gate path with optional recovery context prefilled.
  static String inviteGatePathWithCode(String code, {String? error}) {
    final queryParameters = <String, String>{'code': code};

    if (error != null && error.isNotEmpty) {
      queryParameters['error'] = error;
    }

    return Uri(
      path: inviteGatePath,
      queryParameters: queryParameters,
    ).toString();
  }

  const WelcomeScreen({this.initialSelectedPubkeyHex, super.key});

  /// Optional pubkey to pre-select on the welcome screen.
  final String? initialSelectedPubkeyHex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(currentAuthStateProvider);

    // Gate on `checking` and `authenticated` to show a blank scaffold and
    // prevent the full welcome UI from flashing during startup auto-login.
    //
    // - `checking`: set exclusively during startup (AuthService.initialize).
    //   Blank scaffold here covers the window before auth resolves.
    //
    // - `authenticated`: covers the brief window AFTER auth resolves but
    //   BEFORE GoRouter navigates away from /welcome. When _setAuthState
    //   emits `authenticated`, both Riverpod's currentAuthStateProvider and
    //   the router's refreshListenable are notified via the same auth stream.
    //   Riverpod can rebuild WelcomeScreen with the new state in the same
    //   frame that GoRouter is completing its navigation to /home, causing
    //   the full hero+buttons UI to render for one frame before unmount.
    //   Rendering the blank scaffold during this transient closes the race.
    //
    // We intentionally do NOT gate on `authenticating` because that state is
    // also set during runtime sign-in flows (signInForAccount, importFromNsec,
    // connectWithBunker, etc.). Gating on it would unmount the BlocProvider,
    // disposing the WelcomeBloc mid-event-handler and breaking error navigation.
    //
    // For the `checking` gate to be sufficient during init, AuthService
    // ._setAuthState suppresses the intermediate `checking → authenticating`
    // transition, so session restore goes straight from `checking` to a
    // terminal state (authenticated/unauthenticated/awaitingTosAcceptance).
    // See auth_service.dart `_setAuthState` for that half of the fix.
    if (authState == AuthState.checking ||
        authState == AuthState.authenticated) {
      return const Scaffold(backgroundColor: VineTheme.backgroundColor);
    }

    final authService = ref.watch(authServiceProvider);
    final db = ref.watch(databaseProvider);

    final isAuthenticating = authState == AuthState.authenticating;

    return BlocProvider(
      create: (_) =>
          WelcomeBloc(
            userProfilesDao: db.userProfilesDao,
            authService: authService,
          )..add(
            WelcomeStarted(initialSelectedPubkeyHex: initialSelectedPubkeyHex),
          ),
      child: _WelcomeView(
        isAuthenticating: isAuthenticating,
        lastError: authService.lastError,
      ),
    );
  }
}

/// Welcome screen — View that consumes [WelcomeBloc] state.
class _WelcomeView extends StatelessWidget {
  const _WelcomeView({required this.isAuthenticating, required this.lastError});

  /// Whether auth is in the `authenticating` state (sign-in in progress).
  final bool isAuthenticating;

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
            context.push(WelcomeScreen.inviteGatePath);
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
        final isLoading = isAuthenticating || state.isAccepting;

        final isReturningUser = state.hasReturningUsers;
        return Scaffold(
          backgroundColor: isReturningUser
              ? VineTheme.navGreen
              : VineTheme.backgroundColor,
          appBar: isReturningUser
              ? DiVineAppBar(
                  title: '',
                  leadingIcon: SvgIconSource(DivineIconName.x.assetPath),
                  onLeadingPressed: () {
                    final bloc = context.read<WelcomeBloc>();
                    // If a specific account was pre-selected (account-switcher
                    // flow), cancel the switch and restore the previous account.
                    // Otherwise, sign back in with the default selected account.
                    if (bloc.state.selectedPubkeyHex != null) {
                      bloc.add(const WelcomeCancelSwitchRequested());
                    } else {
                      bloc.add(const WelcomeLogBackInRequested());
                    }
                  },
                )
              : null,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: isReturningUser
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
          DivineButton(
            label: 'Create a new Divine account',
            expanded: true,
            onPressed: () => context.read<WelcomeBloc>().add(
              const WelcomeCreateAccountRequested(),
            ),
          ),

          const SizedBox(height: 12),

          DivineButton(
            label: 'Sign in with a different account',
            expanded: true,
            type: .secondary,
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

  @override
  Widget build(BuildContext context) {
    final account = state.selectedAccount;
    if (account == null) return const SizedBox.shrink();

    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              // Profile section
              _ReturningUserProfile(
                pubkeyHex: account.pubkeyHex,
                profile: account.profile,
              ),

              const Spacer(),

              if (lastError != null) ...[
                ErrorMessage(message: lastError),
                const SizedBox(height: 16),
              ],

              // Sign back in button (primary)
              DivineButton(
                label: 'Sign back in',
                isLoading: isLoading,
                expanded: true,
                onPressed: () => context.read<WelcomeBloc>().add(
                  const WelcomeLogBackInRequested(),
                ),
              ),

              const SizedBox(height: 12),

              // Login with different account (secondary)
              DivineButton(
                label: 'Sign in with a different account',
                expanded: true,
                type: .secondary,
                onPressed: isLoading
                    ? null
                    : () => context.read<WelcomeBloc>().add(
                        const WelcomeLoginOptionsRequested(),
                      ),
              ),

              const SizedBox(height: 12),

              // Create new account (tertiary)
              DivineButton(
                label: 'Create a new Divine account',
                expanded: true,
                type: .secondary,
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
          ),
        ),
      ],
    );
  }
}

/// Displays the returning user's avatar, display name, identifier, and auth
/// source badge.
class _ReturningUserProfile extends StatelessWidget {
  const _ReturningUserProfile({required this.pubkeyHex, required this.profile});

  final String pubkeyHex;
  final UserProfile? profile;

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
        ),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: VineTheme.headlineSmallFont(color: VineTheme.onSurface),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          identifier,
          style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _AvatarWithSwitchButton extends StatelessWidget {
  const _AvatarWithSwitchButton({
    required this.imageUrl,
    required this.displayName,
  });

  final String? imageUrl;
  final String displayName;

  static const double _avatarSize = 144;

  @override
  Widget build(BuildContext context) {
    return UserAvatar(imageUrl: imageUrl, name: displayName, size: _avatarSize);
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
      textScaler: MediaQuery.textScalerOf(context),
      text: TextSpan(
        style: VineTheme.bodySmallFont(color: VineTheme.secondaryText),
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
