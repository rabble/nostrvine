// ABOUTME: App-level construction of the baseline Divine video serving policy.
// ABOUTME: Combines ProofMode certification with the curated classic Vine allowlist.

import 'package:models/models.dart';
import 'package:openvine/constants/allowed_classic_vine_pubkeys.dart';

const divineVideoServingPolicy = VideoServingPolicy(
  allowedClassicVinePubkeys: allowedClassicVinePubkeys,
);
