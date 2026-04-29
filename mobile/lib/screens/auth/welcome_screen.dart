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
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/startup_performance_service.dart';
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
  static String inviteGatePathWithCode(
    String code, {
    String? error,
    String? sourceSlug,
  }) {
    final queryParameters = <String, String>{'code': code};

    if (error != null && error.isNotEmpty) {
      queryParameters['error'] = error;
    }
    if (sourceSlug != null && sourceSlug.isNotEmpty) {
      queryParameters['sourceSlug'] = sourceSlug;
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
    final authService = ref.watch(authServiceProvider);
    final db = ref.watch(databaseProvider);

    final isAuthLoading =
        authState == AuthState.checking ||
        authState == AuthState.authenticating;

    return BlocProvider(
      create: (_) =>
          WelcomeBloc(
            userProfilesDao: db.userProfilesDao,
            authService: authService,
          )..add(
            WelcomeStarted(initialSelectedPubkeyHex: initialSelectedPubkeyHex),
          ),
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
          current.status == WelcomeStatus.error ||
          current.status == WelcomeStatus.sessionExpired,
      listener: (context, state) {
        switch (state.status) {
          case WelcomeStatus.navigatingToCreateAccount:
            context.push(WelcomeScreen.inviteGatePath);
          case WelcomeStatus.navigatingToLoginOptions:
            context.push(WelcomeScreen.loginOptionsPath);
          case WelcomeStatus.sessionExpired:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.authSessionExpired),
                backgroundColor: VineTheme.error,
              ),
            );
          case WelcomeStatus.error:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.authSignInFailed),
                backgroundColor: VineTheme.error,
              ),
            );
          default:
            break;
        }
      },
      builder: (context, state) {
        if (state.status == WelcomeStatus.loaded) {
          StartupPerformanceService.instance.markAuthShellReady();
        }

        final isLoading = isAuthLoading || state.isAccepting;

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
            label: context.l10n.authCreateNewAccount,
            expanded: true,
            onPressed: () => context.read<WelcomeBloc>().add(
              const WelcomeCreateAccountRequested(),
            ),
          ),

          const SizedBox(height: 12),

          DivineButton(
            label: context.l10n.authSignInDifferentAccount,
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
                label: context.l10n.authSignBackIn,
                isLoading: isLoading,
                expanded: true,
                onPressed: () => context.read<WelcomeBloc>().add(
                  const WelcomeLogBackInRequested(),
                ),
              ),

              const SizedBox(height: 12),

              // Login with different account (secondary)
              DivineButton(
                label: context.l10n.authSignInDifferentAccount,
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
                label: context.l10n.authCreateNewAccount,
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
          pubkeyHex: pubkeyHex,
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
    required this.pubkeyHex,
  });

  final String? imageUrl;
  final String displayName;
  final String pubkeyHex;

  static const double _avatarSize = 144;

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      imageUrl: imageUrl,
      name: displayName,
      placeholderSeed: pubkeyHex,
      size: _avatarSize,
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
      textScaler: MediaQuery.textScalerOf(context),
      text: TextSpan(
        style: VineTheme.bodySmallFont(color: VineTheme.secondaryText),
        children: [
          TextSpan(text: context.l10n.authTermsPrefix),
          TextSpan(
            text: context.l10n.authTermsOfService,
            style: linkStyle,
            recognizer: _termsRecognizer,
          ),
          const TextSpan(text: ', '),
          TextSpan(
            text: context.l10n.authPrivacyPolicy,
            style: linkStyle,
            recognizer: _privacyRecognizer,
          ),
          TextSpan(text: context.l10n.authTermsAnd),
          TextSpan(
            text: context.l10n.authSafetyStandards,
            style: linkStyle,
            recognizer: _safetyRecognizer,
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}
