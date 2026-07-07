import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/badges/nip58_badge_models.dart';
import 'package:openvine/services/badges/nip58_badge_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef BadgeCurrentPubkeyReader = String? Function();

typedef BadgeEventSigner =
    Future<Event?> Function({
      required int kind,
      required String content,
      required List<List<String>> tags,
    });

class BadgeDashboardData {
  const BadgeDashboardData({required this.awarded, required this.issued});

  final List<BadgeAwardViewData> awarded;
  final List<IssuedBadgeViewData> issued;
}

class ProfileBadgeViewData {
  const ProfileBadgeViewData({
    required this.badge,
    this.definition,
    this.award,
  });

  final Nip58ProfileBadgeRef badge;
  final Nip58BadgeDefinition? definition;
  final Nip58BadgeAward? award;

  String get awardEventId => badge.awardEventId;
  String get definitionCoordinate => badge.definitionCoordinate;
  String get displayName =>
      definition?.name ?? _definitionNameFromCoordinate(definitionCoordinate);
  String? get description => definition?.description;
  String? get imageUrl =>
      definition?.imageUrl ??
      (definition?.thumbnails.isNotEmpty == true
          ? definition!.thumbnails.first
          : null);
  String? get issuerPubkey => award?.event.pubkey;
  List<String> get recipientPubkeys => award?.recipientPubkeys ?? const [];
  List<String> get uniqueRecipientPubkeys {
    final seen = <String>{};
    return [
      for (final pubkey in recipientPubkeys)
        if (pubkey.isNotEmpty && seen.add(pubkey)) pubkey,
    ];
  }
}

class BadgeAwardViewData {
  const BadgeAwardViewData({
    required this.award,
    this.definition,
    this.isAccepted = false,
    this.isHidden = false,
  });

  final Nip58BadgeAward award;
  final Nip58BadgeDefinition? definition;
  final bool isAccepted;
  final bool isHidden;

  String get awardEventId => award.event.id;
  String get definitionCoordinate => award.definitionCoordinate;
  String get displayName =>
      definition?.name ?? _definitionNameFromCoordinate(definitionCoordinate);
  String? get imageUrl => definition?.imageUrl;
}

class IssuedBadgeViewData {
  const IssuedBadgeViewData({
    required this.award,
    this.definition,
    this.recipients = const [],
  });

  final Nip58BadgeAward award;
  final Nip58BadgeDefinition? definition;
  final List<IssuedBadgeRecipientViewData> recipients;
}

class IssuedBadgeRecipientViewData {
  const IssuedBadgeRecipientViewData({
    required this.pubkey,
    required this.isAccepted,
  });

  final String pubkey;
  final bool isAccepted;
}

class BadgeRepository {
  BadgeRepository({
    required NostrClient nostrClient,
    required SharedPreferences sharedPreferences,
    required BadgeCurrentPubkeyReader currentPubkey,
    required BadgeEventSigner signEvent,
  }) : _nostrClient = nostrClient,
       _sharedPreferences = sharedPreferences,
       _currentPubkey = currentPubkey,
       _signEvent = signEvent;

  final NostrClient _nostrClient;
  final SharedPreferences _sharedPreferences;
  final BadgeCurrentPubkeyReader _currentPubkey;
  final BadgeEventSigner _signEvent;

  Future<BadgeDashboardData> loadDashboard() async {
    final memo = _DashboardLookupMemo();
    final awardedFuture = _loadAwardedBadges(memo);
    final issuedFuture = _loadIssuedBadges(memo);
    await Future.wait<void>([awardedFuture, issuedFuture]);
    return BadgeDashboardData(
      awarded: await awardedFuture,
      issued: await issuedFuture,
    );
  }

  Future<List<BadgeAwardViewData>> loadAwardedBadges() =>
      _loadAwardedBadges(_DashboardLookupMemo());

  Future<List<BadgeAwardViewData>> _loadAwardedBadges(
    _DashboardLookupMemo memo,
  ) async {
    final pubkey = _requireCurrentPubkey();
    final dismissedAwardIds = _dismissedAwardIds(pubkey);
    final awardsFuture = _queryAwardsForRecipient(pubkey);
    final profileBadgesFuture = memo.profileBadges(
      pubkey,
      () => _latestProfileBadges(pubkey),
    );
    // Future.wait (not sequential awaits) so a failure in one query cannot
    // leave the other as an unawaited error.
    final results = await Future.wait<Object?>([
      awardsFuture,
      profileBadgesFuture,
    ]);
    final awards = results[0]! as List<Nip58BadgeAward>;
    final profileBadges = results[1] as Nip58ProfileBadges?;

    final visibleAwards = [
      for (final award in awards)
        if (!dismissedAwardIds.contains(award.event.id)) award,
    ];
    final definitions = await _definitionsByCoordinate(memo, [
      for (final award in visibleAwards) award.definitionCoordinate,
    ]);

    final viewData =
        [
          for (final award in visibleAwards)
            BadgeAwardViewData(
              award: award,
              definition: definitions[award.definitionCoordinate],
              isAccepted: _containsAward(profileBadges, award),
            ),
        ]..sort(
          (left, right) =>
              right.award.event.createdAt.compareTo(left.award.event.createdAt),
        );
    return List<BadgeAwardViewData>.unmodifiable(viewData);
  }

  Future<List<ProfileBadgeViewData>> loadAcceptedBadgesForProfile(
    String pubkey,
  ) async {
    if (pubkey.isEmpty) return const [];

    final profileBadges = await _latestProfileBadges(pubkey);
    final refs = profileBadges?.badges ?? const <Nip58ProfileBadgeRef>[];
    if (refs.isEmpty) return const [];

    final viewData = await Future.wait(
      refs.map((ref) async {
        final definitionFuture = _loadDefinition(ref.definitionCoordinate);
        final awardFuture = _loadAward(ref.awardEventId);

        return ProfileBadgeViewData(
          badge: ref,
          definition: await definitionFuture,
          award: await awardFuture,
        );
      }),
    );

    return List<ProfileBadgeViewData>.unmodifiable(viewData);
  }

  Future<List<IssuedBadgeViewData>> loadIssuedBadges({
    int recipientCheckLimit = 50,
  }) => _loadIssuedBadges(
    _DashboardLookupMemo(),
    recipientCheckLimit: recipientCheckLimit,
  );

  Future<List<IssuedBadgeViewData>> _loadIssuedBadges(
    _DashboardLookupMemo memo, {
    int recipientCheckLimit = 50,
  }) async {
    final pubkey = _requireCurrentPubkey();
    final events = await _nostrClient.queryEvents([
      Filter(authors: [pubkey], kinds: [EventKind.badgeAward], limit: 100),
    ]);

    final awards = events
        .map(Nip58BadgeParser.parseAward)
        .whereType<Nip58BadgeAward>()
        .toList(growable: false);
    List<String> cappedRecipients(Nip58BadgeAward award) => award
        .recipientPubkeys
        .take(recipientCheckLimit)
        .toList(
          growable: false,
        );

    final definitionsFuture = _definitionsByCoordinate(memo, [
      for (final award in awards) award.definitionCoordinate,
    ]);
    final profileBadgesFuture = _profileBadgesByPubkey(memo, [
      for (final award in awards) ...cappedRecipients(award),
    ]);
    final results = await Future.wait<Object?>([
      definitionsFuture,
      profileBadgesFuture,
    ]);
    final definitions = results[0]! as Map<String, Nip58BadgeDefinition?>;
    final profileBadges = results[1]! as Map<String, Nip58ProfileBadges?>;

    final issued =
        [
          for (final award in awards)
            IssuedBadgeViewData(
              award: award,
              definition: definitions[award.definitionCoordinate],
              recipients: List<IssuedBadgeRecipientViewData>.unmodifiable([
                for (final recipientPubkey in cappedRecipients(award))
                  IssuedBadgeRecipientViewData(
                    pubkey: recipientPubkey,
                    isAccepted: _containsAward(
                      profileBadges[recipientPubkey],
                      award,
                    ),
                  ),
              ]),
            ),
        ]..sort(
          (left, right) =>
              right.award.event.createdAt.compareTo(left.award.event.createdAt),
        );
    return List<IssuedBadgeViewData>.unmodifiable(issued);
  }

  Future<Map<String, Nip58BadgeDefinition?>> _definitionsByCoordinate(
    _DashboardLookupMemo memo,
    Iterable<String> coordinates,
  ) async {
    final unique = coordinates.toSet().toList(growable: false);
    final loaded = await Future.wait([
      for (final coordinate in unique)
        memo.definition(coordinate, () => _loadDefinition(coordinate)),
    ]);
    return {for (var i = 0; i < unique.length; i++) unique[i]: loaded[i]};
  }

  Future<Map<String, Nip58ProfileBadges?>> _profileBadgesByPubkey(
    _DashboardLookupMemo memo,
    Iterable<String> pubkeys,
  ) async {
    final unique = pubkeys.toSet().toList(growable: false);
    final loaded = await Future.wait([
      for (final pubkey in unique)
        memo.profileBadges(pubkey, () => _latestProfileBadges(pubkey)),
    ]);
    return {for (var i = 0; i < unique.length; i++) unique[i]: loaded[i]};
  }

  Future<void> acceptAward(BadgeAwardViewData award) async {
    final pubkey = _requireCurrentPubkey();
    final currentProfileBadges = await _latestProfileBadges(pubkey);
    final refs = List<Nip58ProfileBadgeRef>.from(
      currentProfileBadges?.badges ?? const <Nip58ProfileBadgeRef>[],
    );

    final alreadyAccepted = refs.any(
      (ref) =>
          ref.definitionCoordinate == award.award.definitionCoordinate &&
          ref.awardEventId == award.award.event.id,
    );
    if (!alreadyAccepted) {
      refs.add(
        Nip58ProfileBadgeRef(
          definitionCoordinate: award.award.definitionCoordinate,
          awardEventId: award.award.event.id,
        ),
      );
    }

    await _publishProfileBadges(refs);
  }

  Future<void> removeAward(BadgeAwardViewData award) async {
    final pubkey = _requireCurrentPubkey();
    final currentProfileBadges = await _latestProfileBadges(pubkey);
    final refs =
        (currentProfileBadges?.badges ?? const <Nip58ProfileBadgeRef>[])
            .where(
              (ref) =>
                  ref.definitionCoordinate !=
                      award.award.definitionCoordinate ||
                  ref.awardEventId != award.award.event.id,
            )
            .toList(growable: false);

    await _publishProfileBadges(refs);
  }

  Future<void> hideAward(String awardEventId) async {
    final pubkey = _requireCurrentPubkey();
    final dismissed = _dismissedAwardIds(pubkey);
    if (dismissed.add(awardEventId)) {
      await _sharedPreferences.setStringList(
        _dismissedAwardsKey(pubkey),
        dismissed.toList(growable: false),
      );
    }
  }

  Future<List<Nip58BadgeAward>> _queryAwardsForRecipient(String pubkey) async {
    final events = await _nostrClient.queryEvents([
      Filter(kinds: [EventKind.badgeAward], p: [pubkey], limit: 100),
    ]);

    return events
        .map(Nip58BadgeParser.parseAward)
        .whereType<Nip58BadgeAward>()
        .where((award) => award.recipientPubkeys.contains(pubkey))
        .toList(growable: false);
  }

  Future<Nip58ProfileBadges?> _latestProfileBadges(String pubkey) async {
    // Both kinds are queried concurrently; the current kind keeps
    // precedence and legacy is consulted only when it parses to nothing.
    final results = await Future.wait([
      _nostrClient.queryEvents([
        Filter(authors: [pubkey], kinds: [EventKind.profileBadges], limit: 10),
      ]),
      _nostrClient.queryEvents([
        Filter(
          authors: [pubkey],
          kinds: [EventKind.badgeSet],
          d: ['profile_badges'],
          limit: 10,
        ),
      ]),
    ]);
    return _newestParsedProfileBadges(results[0]) ??
        _newestParsedProfileBadges(results[1]);
  }

  Future<Nip58BadgeDefinition?> _loadDefinition(String coordinate) async {
    final parts = _parseCoordinate(coordinate);
    if (parts == null || parts.kind != EventKind.badgeDefinition) {
      return null;
    }

    final events = await _nostrClient.queryEvents([
      Filter(
        authors: [parts.pubkey],
        kinds: [EventKind.badgeDefinition],
        d: [parts.dTag],
        limit: 1,
      ),
    ]);

    if (events.isEmpty) return null;
    final sorted = events.toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return Nip58BadgeParser.parseDefinition(sorted.first);
  }

  Future<Nip58BadgeAward?> _loadAward(String eventId) async {
    if (eventId.isEmpty) return null;

    final events = await _nostrClient.queryEvents([
      Filter(ids: [eventId], kinds: [EventKind.badgeAward], limit: 1),
    ]);
    if (events.isEmpty) return null;

    final sorted = events.toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return Nip58BadgeParser.parseAward(sorted.first);
  }

  Future<void> _publishProfileBadges(List<Nip58ProfileBadgeRef> refs) async {
    final tags = <List<String>>[];
    for (final ref in refs) {
      tags.add(['a', ref.definitionCoordinate]);
      tags.add([
        'e',
        ref.awardEventId,
        if (ref.awardRelay != null && ref.awardRelay!.isNotEmpty)
          ref.awardRelay!,
      ]);
    }

    final event = await _signEvent(
      kind: EventKind.profileBadges,
      content: '',
      tags: tags,
    );
    if (event == null) {
      throw StateError('Could not sign profile badges event');
    }

    final published = await _nostrClient.publishEvent(event);
    if (published is! PublishSuccess) {
      throw StateError('Could not publish profile badges event');
    }
  }

  Set<String> _dismissedAwardIds(String pubkey) {
    return (_sharedPreferences.getStringList(_dismissedAwardsKey(pubkey)) ??
            const <String>[])
        .toSet();
  }

  String _requireCurrentPubkey() {
    final pubkey = _currentPubkey();
    if (pubkey == null || pubkey.isEmpty) {
      throw StateError('Cannot load badges without a current pubkey');
    }
    return pubkey;
  }

  static Nip58ProfileBadges? _newestParsedProfileBadges(List<Event> events) {
    final parsed = events
        .map(Nip58BadgeParser.parseProfileBadges)
        .whereType<Nip58ProfileBadges>()
        .toList(growable: false);
    if (parsed.isEmpty) return null;

    final sorted = parsed.toList()
      ..sort(
        (left, right) => right.event.createdAt.compareTo(left.event.createdAt),
      );
    return sorted.first;
  }

  static bool _containsAward(
    Nip58ProfileBadges? profileBadges,
    Nip58BadgeAward award,
  ) {
    return profileBadges?.badges.any(
          (ref) =>
              ref.definitionCoordinate == award.definitionCoordinate &&
              ref.awardEventId == award.event.id,
        ) ??
        false;
  }

  static ({int kind, String pubkey, String dTag})? _parseCoordinate(
    String coordinate,
  ) {
    final parts = coordinate.split(':');
    if (parts.length < 3) return null;
    final kind = int.tryParse(parts[0]);
    if (kind == null || parts[1].isEmpty) return null;
    return (kind: kind, pubkey: parts[1], dTag: parts.sublist(2).join(':'));
  }

  static String _dismissedAwardsKey(String pubkey) {
    return 'dismissed_badge_awards_$pubkey';
  }
}

/// Deduplicates identical relay lookups within one dashboard load pass.
///
/// Memoizes futures so concurrent requests for the same definition
/// coordinate or pubkey share a single relay query. Created per public
/// load call — never stored on the repository — so a failed pass does not
/// poison a retry with cached errors.
class _DashboardLookupMemo {
  final Map<String, Future<Nip58BadgeDefinition?>> _definitions = {};
  final Map<String, Future<Nip58ProfileBadges?>> _profileBadges = {};

  Future<Nip58BadgeDefinition?> definition(
    String coordinate,
    Future<Nip58BadgeDefinition?> Function() load,
  ) => _definitions.putIfAbsent(coordinate, load);

  Future<Nip58ProfileBadges?> profileBadges(
    String pubkey,
    Future<Nip58ProfileBadges?> Function() load,
  ) => _profileBadges.putIfAbsent(pubkey, load);
}

String _definitionNameFromCoordinate(String coordinate) {
  final parts = coordinate.split(':');
  if (parts.length < 3) return coordinate;
  return parts.sublist(2).join(':');
}
