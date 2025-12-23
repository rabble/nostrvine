// ABOUTME: Token response model from Keycast OAuth token exchange
// ABOUTME: Includes bunker URL, access token, expiry, scope, and policy info

class TokenResponse {
  final String bunkerUrl;
  final String? accessToken;
  final String tokenType;
  final int expiresIn;
  final String? scope;
  final PolicyInfo? policy;

  /// Handle for silent re-authentication (pass to next authorize request)
  final String? authorizationHandle;

  const TokenResponse({
    required this.bunkerUrl,
    this.accessToken,
    this.tokenType = 'Bearer',
    this.expiresIn = 0,
    this.scope,
    this.policy,
    this.authorizationHandle,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      bunkerUrl: json['bunker_url'] as String,
      accessToken: json['access_token'] as String?,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresIn: json['expires_in'] as int? ?? 0,
      scope: json['scope'] as String?,
      policy: json['policy'] != null
          ? PolicyInfo.fromJson(json['policy'] as Map<String, dynamic>)
          : null,
      authorizationHandle: json['authorization_handle'] as String?,
    );
  }
}

class PolicyInfo {
  final String slug;
  final String displayName;
  final String description;
  final List<PermissionDisplay> permissions;

  const PolicyInfo({
    required this.slug,
    required this.displayName,
    required this.description,
    required this.permissions,
  });

  factory PolicyInfo.fromJson(Map<String, dynamic> json) {
    return PolicyInfo(
      slug: json['slug'] as String,
      displayName: json['display_name'] as String? ?? json['slug'] as String,
      description: json['description'] as String? ?? '',
      permissions:
          (json['permissions'] as List<dynamic>?)
              ?.map(
                (e) => PermissionDisplay.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }
}

/// User-friendly permission info from Keycast server
class PermissionDisplay {
  final String icon;
  final String title;
  final String description;

  const PermissionDisplay({
    required this.icon,
    required this.title,
    required this.description,
  });

  factory PermissionDisplay.fromJson(Map<String, dynamic> json) {
    return PermissionDisplay(
      icon: json['icon'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}
