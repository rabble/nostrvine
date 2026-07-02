// ABOUTME: Typed model for Divine-specific profile monetization links.
// ABOUTME: Parses and normalizes outbound support destinations in Kind 0.

import 'package:meta/meta.dart';

const divineMonetizationLinksKey = 'divine_monetization_links';

enum MonetizationLinkCategory {
  tip('tip'),
  subscription('subscription');

  const MonetizationLinkCategory(this.value);

  final String value;

  static MonetizationLinkCategory? fromValue(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    for (final category in values) {
      if (category.value == normalized) return category;
    }
    return null;
  }
}

enum MonetizationLinkProvider {
  cashApp(
    value: 'cash_app',
    displayName: 'Cash App',
    category: MonetizationLinkCategory.tip,
    allowedHosts: {'cash.app'},
  ),
  paypal(
    value: 'paypal',
    displayName: 'PayPal',
    category: MonetizationLinkCategory.tip,
    allowedHosts: {'paypal.me', 'www.paypal.me'},
  ),
  venmo(
    value: 'venmo',
    displayName: 'Venmo',
    category: MonetizationLinkCategory.tip,
    allowedHosts: {'venmo.com', 'www.venmo.com'},
  ),
  patreon(
    value: 'patreon',
    displayName: 'Patreon',
    category: MonetizationLinkCategory.subscription,
    allowedHosts: {'patreon.com', 'www.patreon.com'},
  ),
  substack(
    value: 'substack',
    displayName: 'Substack',
    category: MonetizationLinkCategory.subscription,
    allowedHosts: {'substack.com', 'www.substack.com'},
    allowSubdomains: true,
  ),
  medium(
    value: 'medium',
    displayName: 'Medium',
    category: MonetizationLinkCategory.subscription,
    allowedHosts: {'medium.com', 'www.medium.com'},
  ),
  openCollective(
    value: 'open_collective',
    displayName: 'Open Collective',
    category: MonetizationLinkCategory.subscription,
    allowedHosts: {'opencollective.com', 'www.opencollective.com'},
  );

  const MonetizationLinkProvider({
    required this.value,
    required this.displayName,
    required this.category,
    required this.allowedHosts,
    this.allowSubdomains = false,
  });

  final String value;
  final String displayName;
  final MonetizationLinkCategory category;
  final Set<String> allowedHosts;
  final bool allowSubdomains;

  static MonetizationLinkProvider? fromValue(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    for (final provider in values) {
      if (provider.value == normalized) return provider;
    }
    return null;
  }

  bool allowsHost(String host) {
    final lower = host.toLowerCase();
    if (allowedHosts.contains(lower)) return true;
    return allowSubdomains &&
        allowedHosts.any((allowed) => lower.endsWith('.$allowed'));
  }
}

@immutable
class MonetizationLink {
  const MonetizationLink({
    required this.provider,
    required this.category,
    required this.url,
    required this.enabled,
  });

  factory MonetizationLink.fromJson(Map<String, dynamic> json) {
    final provider = MonetizationLinkProvider.fromValue(json['provider']);
    if (provider == null) {
      throw ArgumentError.value(json['provider'], 'provider');
    }
    final category =
        MonetizationLinkCategory.fromValue(json['category']) ??
        provider.category;
    final url = json['url']?.toString().trim();
    if (url == null || url.isEmpty) {
      throw ArgumentError.value(json['url'], 'url');
    }
    final enabled = json['enabled'] is! bool || json['enabled'] as bool;
    return MonetizationLink(
      provider: provider,
      category: category,
      url: url,
      enabled: enabled,
    );
  }

  final MonetizationLinkProvider provider;
  final MonetizationLinkCategory category;
  final String url;
  final bool enabled;

  Map<String, dynamic> toJson() => {
    'provider': provider.value,
    'category': category.value,
    'url': url,
    'enabled': enabled,
  };

  MonetizationLink copyWith({
    MonetizationLinkProvider? provider,
    MonetizationLinkCategory? category,
    String? url,
    bool? enabled,
  }) {
    final nextProvider = provider ?? this.provider;
    return MonetizationLink(
      provider: nextProvider,
      category: category ?? nextProvider.category,
      url: url ?? this.url,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonetizationLink &&
          provider == other.provider &&
          category == other.category &&
          url == other.url &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(provider, category, url, enabled);
}

sealed class MonetizationLinkInputResult {
  const MonetizationLinkInputResult();
}

final class MonetizationLinkInputValid extends MonetizationLinkInputResult {
  const MonetizationLinkInputValid(this.link);

  final MonetizationLink link;
}

final class MonetizationLinkInputInvalid extends MonetizationLinkInputResult {
  const MonetizationLinkInputInvalid(this.reason);

  final MonetizationLinkInputInvalidReason reason;
}

enum MonetizationLinkInputInvalidReason { empty, invalidFormat, wrongProvider }

List<MonetizationLink> parseMonetizationLinks(Object? raw) {
  if (raw is! List) return const [];
  final links = <MonetizationLink>[];
  for (final item in raw) {
    if (item is! Map) continue;
    try {
      final link = MonetizationLink.fromJson(
        item.map((key, value) => MapEntry(key.toString(), value)),
      );
      final uri = Uri.tryParse(link.url);
      if (uri == null ||
          uri.scheme != 'https' ||
          !link.provider.allowsHost(uri.host)) {
        continue;
      }
      links.add(link);
    } on Object {
      continue;
    }
  }
  return List.unmodifiable(links);
}

List<Map<String, dynamic>> encodeMonetizationLinks(
  Iterable<MonetizationLink> links,
) {
  final deduped = <MonetizationLinkProvider, MonetizationLink>{};
  for (final link in links) {
    deduped[link.provider] = link.copyWith(category: link.provider.category);
  }
  final sorted = <MonetizationLink>[];
  for (final provider in MonetizationLinkProvider.values) {
    final link = deduped[provider];
    if (link != null) sorted.add(link);
  }
  return sorted.map((link) => link.toJson()).toList(growable: false);
}

MonetizationLinkInputResult normalizeMonetizationLinkInput({
  required MonetizationLinkProvider provider,
  required String input,
  required bool enabled,
}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return const MonetizationLinkInputInvalid(
      MonetizationLinkInputInvalidReason.empty,
    );
  }

  final normalized = _normalizedUrlForProvider(provider, trimmed);
  final uri = Uri.tryParse(normalized);
  if (uri == null || uri.scheme != 'https') {
    return const MonetizationLinkInputInvalid(
      MonetizationLinkInputInvalidReason.invalidFormat,
    );
  }
  if (!provider.allowsHost(uri.host)) {
    return const MonetizationLinkInputInvalid(
      MonetizationLinkInputInvalidReason.wrongProvider,
    );
  }
  if ((uri.pathSegments.isEmpty || uri.pathSegments.first.isEmpty) &&
      provider != MonetizationLinkProvider.substack) {
    return const MonetizationLinkInputInvalid(
      MonetizationLinkInputInvalidReason.invalidFormat,
    );
  }

  return MonetizationLinkInputValid(
    MonetizationLink(
      provider: provider,
      category: provider.category,
      url: uri.toString(),
      enabled: enabled,
    ),
  );
}

String _normalizedUrlForProvider(
  MonetizationLinkProvider provider,
  String input,
) {
  final withScheme = input.startsWith(RegExp('https?://', caseSensitive: false))
      ? input
      : null;
  if (withScheme != null) return withScheme;

  final value = input.replaceFirst(RegExp('^@'), '');
  return switch (provider) {
    MonetizationLinkProvider.cashApp =>
      'https://cash.app/\$${value.replaceFirst(RegExp(r'^\$'), '')}',
    MonetizationLinkProvider.paypal => 'https://paypal.me/$value',
    MonetizationLinkProvider.venmo => 'https://venmo.com/u/$value',
    MonetizationLinkProvider.patreon => 'https://www.patreon.com/$value',
    MonetizationLinkProvider.substack =>
      value.contains('.') ? 'https://$value' : 'https://$value.substack.com',
    MonetizationLinkProvider.medium => 'https://medium.com/@$value',
    MonetizationLinkProvider.openCollective =>
      'https://opencollective.com/$value',
  };
}
