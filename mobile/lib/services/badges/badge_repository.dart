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
    final awarded = await loadAwardedBadges();
    final issued = await loadIssuedBadges();
    return BadgeDashboardData(awarded: awarded, issued: issued);
  }

  Future<List<BadgeAwardViewData>> loadAwardedBadges() async {
    final pubkey = _requireCurrentPubkey();
    final dismissedAwardIds = _dismissedAwardIds(pubkey);
    final awards = await _queryAwardsForRecipient(pubkey);
    final profileBadges = await _latestProfileBadges(pubkey);

    final viewData = <BadgeAwardViewData>[];
    for (final award in awards) {
      if (dismissedAwardIds.contains(award.event.id)) continue;

      final definition = await _loadDefinition(award.definitionCoordinate);
      viewData.add(
        BadgeAwardViewData(
          award: award,
          definition: definition,
          isAccepted: _containsAward(profileBadges, award),
        ),
      );
    }

    viewData.sort(
      (left, right) => right.award.event.createdAt.compareTo(
        left.award.event.createdAt,
      ),
    );
    return List<BadgeAwardViewData>.unmodifiable(viewData);
  }

  Future<List<IssuedBadgeViewData>> loadIssuedBadges({
    int recipientCheckLimit = 50,
  }) async {
    final pubkey = _requireCurrentPubkey();
    final events = await _nostrClient.queryEvents([
      Filter(authors: [pubkey], kinds: [EventKind.badgeAward], limit: 100),
    ]);

    final issued = <IssuedBadgeViewData>[];
    for (final event in events) {
      final award = Nip58BadgeParser.parseAward(event);
      if (award == null) continue;

      final definition = await _loadDefinition(award.definitionCoordinate);
      final recipients = <IssuedBadgeRecipientViewData>[];
      for (final recipientPubkey in award.recipientPubkeys.take(
        recipientCheckLimit,
      )) {
        final profileBadges = await _latestProfileBadges(recipientPubkey);
        recipients.add(
          IssuedBadgeRecipientViewData(
            pubkey: recipientPubkey,
            isAccepted: _containsAward(profileBadges, award),
          ),
        );
      }

      issued.add(
        IssuedBadgeViewData(
          award: award,
          definition: definition,
          recipients: List<IssuedBadgeRecipientViewData>.unmodifiable(
            recipients,
          ),
        ),
      );
    }

    issued.sort(
      (left, right) => right.award.event.createdAt.compareTo(
        left.award.event.createdAt,
      ),
    );
    return List<IssuedBadgeViewData>.unmodifiable(issued);
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
    final currentEvents = await _nostrClient.queryEvents([
      Filter(authors: [pubkey], kinds: [EventKind.profileBadges], limit: 10),
    ]);
    final current = _newestParsedProfileBadges(currentEvents);
    if (current != null) return current;

    final legacyEvents = await _nostrClient.queryEvents([
      Filter(
        authors: [pubkey],
        kinds: [EventKind.badgeSet],
        d: ['profile_badges'],
        limit: 10,
      ),
    ]);
    return _newestParsedProfileBadges(legacyEvents);
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
    if (published == null) {
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

String _definitionNameFromCoordinate(String coordinate) {
  final parts = coordinate.split(':');
  if (parts.length < 3) return coordinate;
  return parts.sublist(2).join(':');
}
