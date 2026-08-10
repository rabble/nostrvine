// ABOUTME: Crossposting's names for the shared Divine OAuth callback URL.
// ABOUTME: Aliases only — the canonical parts live in app_oauth_callback.dart
// ABOUTME: so crossposting and verify cannot drift onto different App Links.

import 'package:openvine/services/oauth/app_oauth_callback.dart';

/// Scheme of the crossposting OAuth callback URL.
const String crosspostingOAuthCallbackScheme = appOAuthCallbackScheme;

/// Host of the crossposting OAuth callback URL.
const String crosspostingOAuthCallbackHost = appOAuthCallbackHost;

/// Path of the crossposting OAuth callback URL.
const String crosspostingOAuthCallbackPath = appOAuthCallbackPath;
