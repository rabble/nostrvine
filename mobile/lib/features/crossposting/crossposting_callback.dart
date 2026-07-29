// ABOUTME: Canonical callback URL parts for crossposting OAuth.
// ABOUTME: Shared by the OAuth launcher and the settings cubit so the two
// ABOUTME: callback validators can never drift apart.

/// Scheme of the crossposting OAuth callback URL.
const crosspostingOAuthCallbackScheme = 'https';

/// Host of the crossposting OAuth callback URL.
const crosspostingOAuthCallbackHost = 'divine.video';

/// Path of the crossposting OAuth callback URL.
const crosspostingOAuthCallbackPath = '/app/callback';
