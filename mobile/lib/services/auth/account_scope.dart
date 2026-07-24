// ABOUTME: The immutable account boundary for multi-account switching — a
// ABOUTME: container is either SignedOut or SignedIn(session), never a null.

import 'package:equatable/equatable.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/services/auth/nostr_identity.dart';

/// One signed-in account, immutable for the lifetime of the container that
/// holds it.
///
/// The whole point of multi-account switching is that identity never mutates
/// underneath the code that reads it: a switch builds a *new* container with a
/// new [AccountSession] rather than changing the fields of an existing one. So
/// this type carries no setters and is compared by value.
///
/// See `docs/superpowers/specs/2026-07-24-multi-account-switching-design.md`
/// §8.1.
class AccountSession extends Equatable {
  const AccountSession({
    required this.pubkeyHex,
    required this.identity,
    required this.source,
    this.relays = const [],
  });

  /// Hex-encoded public key of the signed-in account.
  final String pubkeyHex;

  /// The signer for this account (local key, bunker, amber, or Keycast).
  final NostrIdentity identity;

  /// How this account authenticated — determines the restore path.
  final AuthenticationSource source;

  /// The account's configured relays, if known at construction time.
  final List<String> relays;

  @override
  List<Object?> get props => [pubkeyHex, identity, source, relays];
}

/// Whether a container is bound to an account or is signed out.
///
/// Signed-out is a real, reachable state (first launch, onboarding, the welcome
/// screen, sign-out-to-nobody), so it is modelled as its own case rather than a
/// nullable [AccountSession]. A nullable session would push "no account yet"
/// handling onto every consumer — the shape of the #3503 cold-start race — so
/// the sealed type keeps that state explicit and un-ignorable.
///
/// See the design doc §8.1.1.
sealed class AccountScope {
  const AccountScope();

  /// The active account's hex pubkey, or null when signed out.
  ///
  /// This is the single accessor the deprecated `currentPublicKeyHex`
  /// forwarder reads once Phase 3 lands, so existing call sites keep their
  /// nullable semantics unchanged.
  String? get activePubkeyHex;
}

/// No account is bound to this container.
class SignedOut extends AccountScope {
  const SignedOut();

  @override
  String? get activePubkeyHex => null;

  @override
  bool operator ==(Object other) => other is SignedOut;

  @override
  int get hashCode => (SignedOut).hashCode;
}

/// The container is bound to exactly one [session].
class SignedIn extends AccountScope {
  const SignedIn(this.session);

  final AccountSession session;

  @override
  String? get activePubkeyHex => session.pubkeyHex;

  @override
  bool operator ==(Object other) =>
      other is SignedIn && other.session == session;

  @override
  int get hashCode => session.hashCode;
}
