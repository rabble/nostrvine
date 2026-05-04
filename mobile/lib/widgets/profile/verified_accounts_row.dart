// ABOUTME: VerifiedAccountsRow — wraps verified-account chips under a profile.

import 'package:flutter/material.dart';
import 'package:openvine/widgets/profile/verified_account_chip.dart';
import 'package:profile_repository/profile_repository.dart';

/// Wrap of [VerifiedAccountChip]s for a profile's verified identity claims.
///
/// Renders nothing when [claims] is empty.
class VerifiedAccountsRow extends StatelessWidget {
  /// Creates a [VerifiedAccountsRow] for [claims].
  const VerifiedAccountsRow({required this.claims, super.key});

  /// The verified claims to render. Each becomes one [VerifiedAccountChip].
  final List<IdentityClaim> claims;

  @override
  Widget build(BuildContext context) {
    if (claims.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in claims) VerifiedAccountChip(claim: c),
      ],
    );
  }
}
