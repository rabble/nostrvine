// ABOUTME: App-shell scope that eagerly provides the two inbox badge cubits
// ABOUTME: (DM unread + notification) and re-points them at fresh repositories
// ABOUTME: when auth/account state flips. Shared by main.dart and its test so
// ABOUTME: the `lazy: false` eager-create flags (#6115) stay pinned.

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/widgets/dm_restriction_gate_sync.dart';

/// Provides the app-shell inbox badge cubits ([DmUnreadCountCubit] and
/// [NotificationBadgeCubit]) above `MaterialApp` and keeps them pointed at the
/// live repositories as auth/account state changes.
///
/// Both cubits are created **eagerly** (`lazy: false`). The descendant
/// [_InboxBadgeRepositorySync] `context.read`s them from inside Riverpod
/// notifications. [DmUnreadCountCubit]'s create reads three repository
/// providers, so a lazy create triggered from that listener re-enters itself
/// when its own `ref.read` flushes another still-dirty provider of the same
/// invalidation wave, and the re-entrant read throws a `Null`-cast `TypeError`
/// (#6115). [NotificationBadgeCubit] reads a single provider and cannot
/// self-flush today, but is `context.read` from the same listener and one
/// refactor from the same trap, so it is created eagerly too. Creating both
/// during this widget's build — before the sync listener can register — means
/// no create can start inside a Riverpod notification.
///
/// `main.dart` and `app_shell_badge_scope_test.dart` pump this same widget, so
/// the `lazy: false` flags are pinned: flipping either back to lazy turns the
/// eager-create test red.
class AppShellBadgeScope extends ConsumerWidget {
  /// Creates the badge scope wrapping [child].
  const AppShellBadgeScope({required this.child, super.key});

  /// The subtree rendered below the badge cubits (the rest of the app shell).
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          lazy: false,
          create: (_) => DmUnreadCountCubit(
            dmRepository: ref.read(dmRepositoryProvider),
            followRepository: ref.read(followRepositoryProvider),
            contentBlocklistRepository: ref.read(
              contentBlocklistRepositoryProvider,
            ),
            protectedMinorInboxGate: ref.read(protectedMinorInboxGateProvider),
          ),
        ),
        // Keep the provider identity stable so repository readiness / account
        // switches do not remount MaterialApp and AppShell; the sync widget
        // below swaps only the cubit's stream subscription when the repository
        // identity changes.
        BlocProvider(
          lazy: false,
          create: (_) => NotificationBadgeCubit(
            repository: ref.read(notificationRepositoryProvider),
          ),
        ),
      ],
      child: _InboxBadgeRepositorySync(child: child),
    );
  }
}

/// Re-points the app-shell badge cubits at fresh repository instances when
/// their providers rebuild (Nostr/auth becomes ready, account switch).
///
/// Both [NotificationBadgeCubit] and [DmUnreadCountCubit] are provided once
/// above MaterialApp via `ref.read`, so without this they keep their captured
/// pre-auth repositories and silently undercount. The DM repositories
/// (`dmRepositoryProvider` / `followRepositoryProvider` /
/// `contentBlocklistRepositoryProvider`) all `ref.watch(nostrServiceProvider)`
/// and so rebuild on auth-ready. Swapping only the cubit subscriptions avoids
/// remounting MaterialApp/AppShell.
class _InboxBadgeRepositorySync extends ConsumerWidget {
  const _InboxBadgeRepositorySync({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(notificationRepositoryProvider, (_, repository) {
      context.read<NotificationBadgeCubit>().setRepository(repository);
    });

    void syncDmUnread() {
      context.read<DmUnreadCountCubit>().setRepositories(
        dmRepository: ref.read(dmRepositoryProvider),
        followRepository: ref.read(followRepositoryProvider),
        contentBlocklistRepository: ref.read(
          contentBlocklistRepositoryProvider,
        ),
      );
    }

    ref
      ..listen(dmRepositoryProvider, (_, _) => syncDmUnread())
      ..listen(followRepositoryProvider, (_, _) => syncDmUnread())
      ..listen(contentBlocklistRepositoryProvider, (_, _) => syncDmUnread());

    // #176: pump DM-restriction flips into the shared inbox gate so the badge
    // (and any mounted list) re-filters without waiting for a new DM event.
    return DmRestrictionGateSync(child: child);
  }
}
