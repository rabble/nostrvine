import 'package:badge_repository/src/badge_coordinate.dart';
import 'package:badge_repository/src/nip58_badge_models.dart';
import 'package:badge_repository/src/nip58_badge_parser.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef BadgeCurrentPubkeyReader = String? Function();

// Trust-safety bulk actions must stay bounded even when a public badge is
// claimed by a very large group. These limits keep relay/cache reads finite:
// first discover the newest claim events, then verify latest profile-badge
// state in author chunks instead of issuing per-claimant REQs.
const int _claimantCandidateEventLimit = 1000;
const int _claimantProfileAuthorChunkSize = 100;
const int _profileBadgeEventsPerAuthorLimit = 10;

typedef BadgeEventSigner =
    Future<Event?> Function({
      required int kind,
      required String content,
      required List<List<String>> tags,
    });

class BadgeDashboardData {
  const BadgeDashboardData({
    required this.awarded,
    required this.issued,
    required this.created,
    this.hidden = const [],
  });

  /// Awards addressed to the user that they have not dismissed.
  final List<BadgeAwardViewData> awarded;

  final List<IssuedBadgeViewData> issued;
  final List<CreatedBadgeViewData> created;

  /// Awards the user dismissed on this device.
  ///
  /// Kept alongside [awarded] rather than dropped, so a dismissal made by
  /// accident can be taken back.
  final List<BadgeAwardViewData> hidden;
}

/// The fields of a badge definition the current user is about to publish.
///
/// Creating and editing use the same shape: [identifier] is the `d` tag, so
/// reusing an existing identifier replaces that badge rather than adding one.
class BadgeDefinitionDraft {
  /// Creates a draft definition.
  const BadgeDefinitionDraft({
    required this.identifier,
    required this.name,
    required this.imageUrl,
    this.description = '',
    this.thumbnailUrl = '',
  });

  /// The `d` tag; stable across edits.
  final String identifier;

  /// Display name shown on the badge.
  final String name;

  /// Free-text description of what the badge means.
  final String description;

  /// Badge artwork URL, typically a Blossom blob. Required.
  final String imageUrl;

  /// Optional separate thumbnail URL.
  ///
  /// The mobile editor does not offer a separate thumbnail, but carries the
  /// existing one through an edit so a badge created on the web keeps it.
  final String thumbnailUrl;
}

/// A badge definition authored by the current user, with award totals.
class CreatedBadgeViewData {
  /// Creates created-badge view data.
  const CreatedBadgeViewData({
    required this.definition,
    this.awardCount = 0,
    this.recipientCount = 0,
  });

  final Nip58BadgeDefinition definition;

  /// Number of award events published for this badge.
  final int awardCount;

  /// Number of distinct pubkeys awarded this badge.
  final int recipientCount;

  String get coordinate => definition.coordinate;
  String get displayName => definition.name ?? definition.dTag;
  String? get imageUrl =>
      definition.imageUrl ??
      (definition.thumbnails.isNotEmpty ? definition.thumbnails.first : null);
}

/// One awardee of a badge, with whether they pinned it to their profile.
class BadgeRecipientViewData {
  /// Creates recipient view data.
  const BadgeRecipientViewData({
    required this.pubkey,
    required this.awardEventId,
    required this.isAccepted,
  });

  final String pubkey;

  /// The award event that named this recipient.
  final String awardEventId;

  /// Whether the recipient's profile badge list references [awardEventId].
  ///
  /// Null when acceptance was not resolved for this recipient, which happens
  /// past the recipient-check limit. Everyone awarded the badge is still
  /// listed; only the status is unknown.
  final bool? isAccepted;
}

/// Everything the badge detail screen renders for one badge coordinate.
class BadgeDetailData {
  /// Creates badge detail data.
  const BadgeDetailData({
    required this.coordinate,
    required this.definition,
    required this.recipients,
    required this.isOwner,
    this.viewerAward,
  });

  final BadgeCoordinate coordinate;

  /// Null when no definition event for [coordinate] could be found.
  final Nip58BadgeDefinition? definition;

  final List<BadgeRecipientViewData> recipients;

  /// Whether the current user issued this badge and may award or edit it.
  final bool isOwner;

  /// The award naming the current user, when they are an awardee.
  final BadgeAwardViewData? viewerAward;
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

/// One badge the current user has awarded, with everyone who received it.
///
/// Grouped by badge rather than by award event: awarding the same badge to
/// someone a second time is a normal thing to do (their first award may have
/// been dismissed), and listing both would leave a row that can never resolve.
class IssuedBadgeViewData {
  /// Creates issued-badge view data.
  const IssuedBadgeViewData({
    required this.coordinate,
    this.definition,
    this.recipients = const [],
    this.latestAwardedAt = 0,
  });

  /// Address of the awarded badge.
  final String coordinate;

  final Nip58BadgeDefinition? definition;

  /// Every distinct recipient, each against their newest award.
  final List<IssuedBadgeRecipientViewData> recipients;

  /// Timestamp of the newest award for this badge, used for ordering.
  final int latestAwardedAt;

  /// Badge name, falling back to the identifier when no definition loaded.
  String get displayName =>
      definition?.name ?? _definitionNameFromCoordinate(coordinate);
}

class IssuedBadgeRecipientViewData {
  const IssuedBadgeRecipientViewData({
    required this.pubkey,
    required this.isAccepted,
  });

  final String pubkey;

  /// Null when acceptance was not resolved for this recipient — see
  /// [BadgeRecipientViewData.isAccepted].
  final bool? isAccepted;
}

/// Failure to publish profile badges to at least one relay.
///
/// Carries the relay-level [outcome] for logging and triage.
class BadgePublishException implements Exception {
  const BadgePublishException(this.message, {required this.outcome});

  final String message;
  final PublishOutcome outcome;

  @override
  String toString() => 'BadgePublishException: $message';
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

  /// The profile badge list this repository last published, and whose it is.
  ///
  /// `kind:10008` is replaceable, and [NostrClient] deliberately does not
  /// optimistically cache replaceable events — a stale copy would shadow the
  /// real newest one. That leaves a window right after publishing where the
  /// relay has acknowledged the event but does not serve it yet, so a reload
  /// reads back the *previous* list and an accepted badge still renders as
  /// unaccepted until the user refreshes by hand.
  ///
  /// Holding the published list here closes that window. It is not a cache
  /// with a lifetime: a relay event that is genuinely newer still wins, so it
  /// stops mattering as soon as the relay catches up.
  ({String pubkey, Nip58ProfileBadges badges})? _publishedProfileBadges;

  /// Badge definitions this repository published, keyed by coordinate.
  ///
  /// Same window as [_publishedProfileBadges], for the same reason:
  /// `kind:30009` is parameterized-replaceable, so it is not optimistically
  /// cached either, and an edit would read the previous definition straight
  /// back — the badge would keep its old name until a manual refresh.
  final Map<String, Nip58BadgeDefinition> _publishedDefinitions = {};

  Future<BadgeDashboardData> loadDashboard() async {
    final memo = _DashboardLookupMemo();
    final awardedFuture = _loadAwardedBadges(memo);
    final issuedFuture = _loadIssuedBadges(memo);
    final createdFuture = _loadCreatedBadges(memo);
    await Future.wait<void>([awardedFuture, issuedFuture, createdFuture]);
    final awarded = await awardedFuture;
    return BadgeDashboardData(
      awarded: [
        for (final award in awarded)
          if (!award.isHidden) award,
      ],
      hidden: [
        for (final award in awarded)
          if (award.isHidden) award,
      ],
      issued: await issuedFuture,
      created: await createdFuture,
    );
  }

  /// Every award addressed to the current user, dismissed ones included.
  ///
  /// Dismissed awards come back with [BadgeAwardViewData.isHidden] set rather
  /// than being dropped — the dashboard needs them to offer a way back.
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

    final definitions = await _definitionsByCoordinate(memo, [
      for (final award in awards) award.definitionCoordinate,
    ]);

    // Newest award per badge, the same rule the issued list uses: being
    // awarded a badge twice is normal, and listing both leaves one row that
    // can never resolve.
    final newestPerCoordinate = <String, Nip58BadgeAward>{};
    for (final award in awards) {
      final existing = newestPerCoordinate[award.definitionCoordinate];
      if (existing == null ||
          award.event.createdAt > existing.event.createdAt) {
        newestPerCoordinate[award.definitionCoordinate] = award;
      }
    }

    final viewData =
        [
          for (final award in newestPerCoordinate.values)
            BadgeAwardViewData(
              award: award,
              definition: definitions[award.definitionCoordinate],
              isAccepted: _containsBadgeCoordinate(profileBadges, award),
              isHidden: dismissedAwardIds.contains(award.event.id),
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

    // A profile badge list is its owner's event, so it can reference an award
    // nobody but its own publisher stands behind. When the award event is
    // available, render only awards the badge's issuer actually signed. Missing
    // award events are kept because they may be unavailable on the queried
    // relay while still existing elsewhere.
    return List<ProfileBadgeViewData>.unmodifiable([
      for (final badge in viewData)
        if (badge.award == null || _isIssuedByBadgeOwner(badge.award!)) badge,
    ]);
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
    final awards = await memo.issuedAwards(
      pubkey,
      () => _queryAwardsByAuthor(pubkey),
    );

    // Newest award per (badge, recipient): a re-award supersedes the earlier
    // one rather than adding a second, permanently pending row. Everyone
    // named is kept — the limit below bounds relay lookups, not the list.
    final awardByBadgeAndRecipient = <String, Map<String, Nip58BadgeAward>>{};
    final latestAwardedAt = <String, int>{};
    for (final award in awards) {
      final byRecipient = awardByBadgeAndRecipient.putIfAbsent(
        award.definitionCoordinate,
        () => {},
      );
      latestAwardedAt.update(
        award.definitionCoordinate,
        (current) =>
            current > award.event.createdAt ? current : award.event.createdAt,
        ifAbsent: () => award.event.createdAt,
      );
      for (final recipient in award.recipientPubkeys) {
        final existing = byRecipient[recipient];
        if (existing == null ||
            award.event.createdAt > existing.event.createdAt) {
          byRecipient[recipient] = award;
        }
      }
    }

    final checked = <String>{
      for (final byRecipient in awardByBadgeAndRecipient.values)
        ...byRecipient.keys.take(recipientCheckLimit),
    };

    final results = await Future.wait<Object?>([
      _definitionsByCoordinate(memo, [
        for (final award in awards) award.definitionCoordinate,
      ]),
      _profileBadgesByPubkey(memo, checked),
    ]);
    final definitions = results[0]! as Map<String, Nip58BadgeDefinition?>;
    final profileBadges = results[1]! as Map<String, Nip58ProfileBadges?>;

    final issued =
        [
          for (final entry in awardByBadgeAndRecipient.entries)
            IssuedBadgeViewData(
              coordinate: entry.key,
              definition: definitions[entry.key],
              latestAwardedAt: latestAwardedAt[entry.key]!,
              recipients: List<IssuedBadgeRecipientViewData>.unmodifiable([
                for (final recipient in entry.value.entries)
                  IssuedBadgeRecipientViewData(
                    pubkey: recipient.key,
                    isAccepted: checked.contains(recipient.key)
                        ? _containsBadgeCoordinate(
                            profileBadges[recipient.key],
                            recipient.value,
                          )
                        : null,
                  ),
              ]),
            ),
        ]..sort(
          (left, right) =>
              right.latestAwardedAt.compareTo(left.latestAwardedAt),
        );
    return List<IssuedBadgeViewData>.unmodifiable(issued);
  }

  /// Loads the badge definitions authored by the current user.
  ///
  /// Definitions are addressable, so only the newest event per identifier is
  /// returned, newest first. Award totals count every award the user
  /// published for each definition.
  ///
  /// Throws [StateError] if there is no current pubkey.
  Future<List<CreatedBadgeViewData>> loadCreatedBadges({int limit = 100}) =>
      _loadCreatedBadges(_DashboardLookupMemo(), limit: limit);

  Future<List<CreatedBadgeViewData>> _loadCreatedBadges(
    _DashboardLookupMemo memo, {
    int limit = 100,
  }) async {
    final pubkey = _requireCurrentPubkey();
    final results = await Future.wait<Object?>([
      _ownDefinitions(pubkey, limit: limit),
      memo.issuedAwards(pubkey, () => _queryAwardsByAuthor(pubkey)),
    ]);
    final definitions = results[0]! as List<Nip58BadgeDefinition>;
    final awards = results[1]! as List<Nip58BadgeAward>;

    final awardsByCoordinate = <String, List<Nip58BadgeAward>>{};
    for (final award in awards) {
      awardsByCoordinate
          .putIfAbsent(award.definitionCoordinate, () => [])
          .add(award);
    }

    final created =
        [
          for (final definition in definitions)
            CreatedBadgeViewData(
              definition: definition,
              awardCount:
                  awardsByCoordinate[definition.coordinate]?.length ?? 0,
              recipientCount: <String>{
                for (final award
                    in awardsByCoordinate[definition.coordinate] ??
                        const <Nip58BadgeAward>[])
                  ...award.recipientPubkeys,
              }.length,
            ),
        ]..sort(
          (left, right) => right.definition.event.createdAt.compareTo(
            left.definition.event.createdAt,
          ),
        );
    return List<CreatedBadgeViewData>.unmodifiable(created);
  }

  /// Loads one badge's definition, its awardees, and the viewer's relation
  /// to it.
  ///
  /// Only awards published by the badge's own issuer count, so a third party
  /// cannot inject awardees into someone else's badge. Every awardee is
  /// listed; when more than [recipientCheckLimit] people hold the badge,
  /// acceptance is resolved for that many and left null for the rest, so a
  /// long list costs a bounded number of relay lookups. The viewer's own
  /// status is always resolved.
  Future<BadgeDetailData> loadBadgeDetail(
    BadgeCoordinate coordinate, {
    int recipientCheckLimit = 50,
  }) async {
    final viewerPubkey = _currentPubkey();
    final memo = _DashboardLookupMemo();
    final results = await Future.wait<Object?>([
      memo.definition(
        coordinate.value,
        () => _loadDefinition(coordinate.value),
      ),
      _queryAwardsForCoordinate(coordinate),
    ]);
    final definition = results[0] as Nip58BadgeDefinition?;
    final awards = results[1]! as List<Nip58BadgeAward>;

    // A recipient can be named by more than one award event; the profile
    // badge list references exactly one, so the newest award wins.
    final awardByRecipient = <String, Nip58BadgeAward>{};
    for (final award in awards) {
      for (final recipient in award.recipientPubkeys) {
        final existing = awardByRecipient[recipient];
        if (existing == null ||
            award.event.createdAt > existing.event.createdAt) {
          awardByRecipient[recipient] = award;
        }
      }
    }

    final checked = <String>{
      ...awardByRecipient.keys.take(recipientCheckLimit),
      if (viewerPubkey != null && awardByRecipient.containsKey(viewerPubkey))
        viewerPubkey,
    };
    final profileBadges = await _profileBadgesByPubkey(memo, checked);

    final recipients = [
      for (final entry in awardByRecipient.entries)
        BadgeRecipientViewData(
          pubkey: entry.key,
          awardEventId: entry.value.event.id,
          isAccepted: checked.contains(entry.key)
              ? _containsBadgeCoordinate(profileBadges[entry.key], entry.value)
              : null,
        ),
    ];

    final viewerAward = viewerPubkey == null
        ? null
        : awardByRecipient[viewerPubkey];
    return BadgeDetailData(
      coordinate: coordinate,
      definition: definition,
      recipients: List<BadgeRecipientViewData>.unmodifiable(recipients),
      isOwner: viewerPubkey != null && viewerPubkey == coordinate.pubkey,
      viewerAward: viewerAward == null
          ? null
          : BadgeAwardViewData(
              award: viewerAward,
              definition: definition,
              isAccepted: _containsBadgeCoordinate(
                profileBadges[viewerPubkey],
                viewerAward,
              ),
            ),
    );
  }

  /// Loads pubkeys whose latest profile-badge list claims [coordinate].
  ///
  /// NIP-58 profile badges are currently published as kind 10008 and, for
  /// older clients, legacy kind 30008 with `d=profile_badges`. The initial
  /// reverse `#a` query finds candidate claimants without walking every award
  /// recipient; each candidate is then checked against their latest profile
  /// badge list so an older claim does not survive after a newer removal.
  Future<Set<String>> loadClaimantPubkeys(BadgeCoordinate coordinate) async {
    final viewerPubkey = _currentPubkey();
    final candidateEvents = await _queryProfileBadgeClaimsForCoordinate(
      coordinate,
    );
    final candidatePubkeys = {
      for (final event in candidateEvents)
        if (event.pubkey != viewerPubkey) event.pubkey,
    };
    if (candidatePubkeys.isEmpty) return const {};

    final memo = _DashboardLookupMemo();
    final latestByPubkey = await _profileBadgesByPubkeyChunked(
      memo,
      candidatePubkeys,
    );

    return Set.unmodifiable({
      for (final entry in latestByPubkey.entries)
        if (_containsBadgeCoordinateValue(entry.value, coordinate.value))
          entry.key,
    });
  }

  /// Publishes a badge definition (`kind:30009`) authored by the current user.
  ///
  /// Badge definitions are addressable, so publishing a draft whose
  /// identifier already exists edits that badge in place instead of adding a
  /// second one.
  ///
  /// Throws:
  ///
  /// * [ArgumentError] if the draft has no identifier, no name, or no
  ///   artwork.
  /// * [StateError] if there is no current pubkey or the event cannot be
  ///   signed into a valid definition.
  /// * [BadgePublishException] when no relay accepts the definition.
  Future<Nip58BadgeDefinition> saveDefinition(
    BadgeDefinitionDraft draft,
  ) async {
    _requireCurrentPubkey();

    final identifier = draft.identifier.trim();
    if (identifier.isEmpty) {
      throw ArgumentError.value(
        draft.identifier,
        'identifier',
        'Badge identifier must not be empty',
      );
    }
    final name = draft.name.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(
        draft.name,
        'name',
        'Badge name must not be empty',
      );
    }

    final imageUrl = draft.imageUrl.trim();
    if (imageUrl.isEmpty) {
      throw ArgumentError.value(
        draft.imageUrl,
        'imageUrl',
        'Badge artwork must not be empty',
      );
    }

    final description = draft.description.trim();
    final thumbnailUrl = draft.thumbnailUrl.trim();
    final event = await _signAndPublish(
      kind: EventKind.badgeDefinition,
      label: 'badge definition',
      tags: [
        ['d', identifier],
        ['name', name],
        // Omitted rather than written empty: an empty tag parses back as ''
        // rather than null, which reads as "has a description" downstream.
        if (description.isNotEmpty) ['description', description],
        ['image', imageUrl],
        if (thumbnailUrl.isNotEmpty) ['thumb', thumbnailUrl],
      ],
    );

    final definition = Nip58BadgeParser.parseDefinition(event);
    if (definition == null) {
      throw StateError('Signed badge definition event is not parseable');
    }
    _publishedDefinitions[definition.coordinate] = definition;
    return definition;
  }

  /// Awards the badge at [coordinate] to [recipientPubkeys] (`kind:8`).
  ///
  /// Duplicate and malformed pubkeys are dropped before publishing.
  ///
  /// Throws:
  ///
  /// * [ArgumentError] if no valid recipient remains.
  /// * [StateError] if there is no current pubkey, the badge belongs to
  ///   someone else, or the event cannot be signed into a valid award.
  /// * [BadgePublishException] when no relay accepts the award.
  Future<Nip58BadgeAward> awardBadge({
    required BadgeCoordinate coordinate,
    required List<String> recipientPubkeys,
  }) async {
    final pubkey = _requireCurrentPubkey();
    // Readers resolve awards through the badge's own issuer, so an award
    // signed by anyone else is an event nothing will ever honour.
    if (coordinate.pubkey != pubkey) {
      throw StateError('Cannot award a badge issued by someone else');
    }

    final recipients = <String>{
      for (final recipientPubkey in recipientPubkeys)
        if (isBadgePubkey(recipientPubkey)) recipientPubkey,
    }.toList(growable: false);
    if (recipients.isEmpty) {
      throw ArgumentError.value(
        recipientPubkeys,
        'recipientPubkeys',
        'Badge award needs at least one valid recipient',
      );
    }

    final event = await _signAndPublish(
      kind: EventKind.badgeAward,
      label: 'badge award',
      tags: [
        ['a', coordinate.value],
        for (final recipient in recipients) ['p', recipient],
      ],
    );

    final award = Nip58BadgeParser.parseAward(event);
    if (award == null) {
      throw StateError('Signed badge award event is not parseable');
    }
    return award;
  }

  /// Requests deletion of the badge at [coordinate] and every award the
  /// current user issued for it.
  ///
  /// Publishes one NIP-09 deletion request (`kind:5`) naming the addressable
  /// definition plus each award event, because an award that outlives its
  /// definition renders as a nameless badge. Two caveats the UI must be
  /// honest about: relays are free to ignore a deletion request, and a
  /// recipient's profile badge list is *their* event — an accepted badge can
  /// keep showing on their profile until they remove it.
  ///
  /// Throws:
  ///
  /// * [StateError] if there is no current pubkey, the badge belongs to
  ///   someone else, or the request cannot be signed.
  /// * [BadgePublishException] when no relay accepts the request.
  Future<void> deleteBadge(BadgeCoordinate coordinate) async {
    final pubkey = _requireCurrentPubkey();
    if (coordinate.pubkey != pubkey) {
      throw StateError('Cannot delete a badge issued by someone else');
    }

    final memo = _DashboardLookupMemo();
    final results = await Future.wait<Object?>([
      memo.definition(
        coordinate.value,
        () => _loadDefinition(coordinate.value),
      ),
      _queryAwardsForCoordinate(coordinate),
    ]);
    final definition = results[0] as Nip58BadgeDefinition?;
    final awards = results[1]! as List<Nip58BadgeAward>;

    await _signAndPublish(
      kind: EventKind.eventDeletion,
      label: 'badge deletion',
      tags: [
        ['a', coordinate.value],
        if (definition != null) ['e', definition.event.id],
        for (final award in awards) ['e', award.event.id],
        ['k', '${EventKind.badgeDefinition}'],
        if (awards.isNotEmpty) ['k', '${EventKind.badgeAward}'],
      ],
    );

    // Only once the request is out: a relay can refuse a deletion, and
    // dropping the badge here first would make a freshly created badge — the
    // case a relay is most likely to refuse — vanish from the dashboard while
    // it still exists and the relay is not serving it yet.
    _publishedDefinitions.remove(coordinate.value);
  }

  /// The `d` identifiers of every badge the current user has published.
  ///
  /// Badge definitions are addressable, so publishing a new one under an
  /// identifier that is already in use replaces that badge rather than adding
  /// a second — including for everyone already holding an award for it. The
  /// editor uses this to refuse that by accident.
  ///
  /// Throws [StateError] if there is no current pubkey.
  Future<Set<String>> loadCreatedIdentifiers({int limit = 100}) async {
    final pubkey = _requireCurrentPubkey();
    return {
      for (final definition in await _ownDefinitions(pubkey, limit: limit))
        definition.dTag,
    };
  }

  Future<List<Event>> _queryDefinitionsByAuthor(
    String pubkey, {
    int limit = 100,
  }) {
    return _nostrClient.queryEvents([
      Filter(
        authors: [pubkey],
        kinds: [EventKind.badgeDefinition],
        limit: limit,
      ),
    ]);
  }

  Future<List<Nip58BadgeAward>> _queryAwardsByAuthor(
    String pubkey, {
    int limit = 100,
  }) async {
    final events = await _nostrClient.queryEvents([
      Filter(authors: [pubkey], kinds: [EventKind.badgeAward], limit: limit),
    ]);
    return events
        .map(Nip58BadgeParser.parseAward)
        .whereType<Nip58BadgeAward>()
        .toList(growable: false);
  }

  Future<List<Nip58BadgeAward>> _queryAwardsForCoordinate(
    BadgeCoordinate coordinate, {
    int limit = 200,
  }) async {
    final events = await _nostrClient.queryEvents([
      Filter(
        authors: [coordinate.pubkey],
        kinds: [EventKind.badgeAward],
        a: [coordinate.value],
        limit: limit,
      ),
    ]);

    final awards =
        events
            .map(Nip58BadgeParser.parseAward)
            .whereType<Nip58BadgeAward>()
            .where((award) => award.definitionCoordinate == coordinate.value)
            .toList()
          ..sort(
            (left, right) =>
                right.event.createdAt.compareTo(left.event.createdAt),
          );
    return awards;
  }

  Future<List<Event>> _queryProfileBadgeClaimsForCoordinate(
    BadgeCoordinate coordinate, {
    int limit = _claimantCandidateEventLimit,
  }) async {
    final events = await _nostrClient.queryEvents([
      Filter(
        kinds: [EventKind.profileBadges, EventKind.badgeSet],
        a: [coordinate.value],
        limit: limit,
      ),
    ]);

    return events
        .where(Nip58BadgeParser.isProfileBadgesEvent)
        .where(
          (event) =>
              Nip58BadgeParser.parseProfileBadges(event)?.badges.any(
                (ref) => ref.definitionCoordinate == coordinate.value,
              ) ??
              false,
        )
        .toList(growable: false);
  }

  static List<Nip58BadgeDefinition> _newestDefinitionPerIdentifier(
    List<Event> events,
  ) {
    final byIdentifier = <String, Nip58BadgeDefinition>{};
    for (final event in events) {
      final definition = Nip58BadgeParser.parseDefinition(event);
      if (definition == null) continue;
      final existing = byIdentifier[definition.dTag];
      if (existing == null ||
          definition.event.createdAt > existing.event.createdAt) {
        byIdentifier[definition.dTag] = definition;
      }
    }
    return byIdentifier.values.toList(growable: false);
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

  Future<Map<String, Nip58ProfileBadges?>> _profileBadgesByPubkeyChunked(
    _DashboardLookupMemo memo,
    Iterable<String> pubkeys,
  ) async {
    final unique = pubkeys.toSet().toList(growable: false);
    final result = <String, Nip58ProfileBadges?>{};
    for (
      var start = 0;
      start < unique.length;
      start += _claimantProfileAuthorChunkSize
    ) {
      final chunkEnd = start + _claimantProfileAuthorChunkSize;
      final end = chunkEnd > unique.length ? unique.length : chunkEnd;
      final chunk = unique.sublist(start, end);
      final badgesByPubkey = await memo.profileBadgeChunk(
        chunk,
        () => _latestProfileBadgesForAuthors(chunk),
      );
      for (final pubkey in chunk) {
        result[pubkey] = badgesByPubkey[pubkey];
      }
    }
    return result;
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

  /// Accepts [award] by publishing the current user's profile badge list.
  ///
  /// Throws:
  ///
  /// * [StateError] if there is no current pubkey or the profile badge event
  ///   cannot be signed.
  /// * [BadgePublishException] when no relay confirms the published list.
  Future<void> acceptAward(BadgeAwardViewData award) async {
    final pubkey = _requireCurrentPubkey();
    final currentProfileBadges = await _latestProfileBadges(pubkey);
    final coordinate = award.award.definitionCoordinate;
    final awardEventId = award.award.event.id;
    final current =
        currentProfileBadges?.badges ?? const <Nip58ProfileBadgeRef>[];

    // Accepting the award that is already pinned changes nothing, and
    // rebuilding the ref would throw away its relay hint.
    final alreadyAccepted = current.any(
      (ref) =>
          ref.definitionCoordinate == coordinate &&
          ref.awardEventId == awardEventId,
    );

    // Otherwise one entry per badge, not per award: being awarded the same
    // badge twice is normal, and appending a second a/e pair for the same
    // coordinate renders the badge twice on the profile.
    final refs = alreadyAccepted
        ? current.toList(growable: false)
        : [
            for (final ref in current)
              if (ref.definitionCoordinate != coordinate) ref,
            Nip58ProfileBadgeRef(
              definitionCoordinate: coordinate,
              awardEventId: awardEventId,
            ),
          ];

    await _publishProfileBadges(refs);
  }

  /// Removes [award] from the current user's profile badge list.
  ///
  /// Throws:
  ///
  /// * [StateError] if there is no current pubkey or the profile badge event
  ///   cannot be signed.
  /// * [BadgePublishException] when no relay confirms the published list.
  Future<void> removeAward(BadgeAwardViewData award) async {
    final pubkey = _requireCurrentPubkey();
    final currentProfileBadges = await _latestProfileBadges(pubkey);
    final refs =
        (currentProfileBadges?.badges ?? const <Nip58ProfileBadgeRef>[])
            .where(
              (ref) =>
                  ref.definitionCoordinate != award.award.definitionCoordinate,
            )
            .toList(growable: false);

    await _publishProfileBadges(refs);
  }

  /// Brings a dismissed award back into the awarded list.
  Future<void> unhideAward(String awardEventId) async {
    final pubkey = _requireCurrentPubkey();
    final dismissed = _dismissedAwardIds(pubkey);
    if (dismissed.remove(awardEventId)) {
      await _sharedPreferences.setStringList(
        _dismissedAwardsKey(pubkey),
        dismissed.toList(growable: false),
      );
    }
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
        .where(_isIssuedByBadgeOwner)
        .toList(growable: false);
  }

  /// Whether [award] was signed by the issuer of the badge it points at.
  ///
  /// A kind 8 naming you is not proof the badge's owner awarded it: this
  /// query filters on `p`, not on the author, so anyone could publish an
  /// award for someone else's coordinate and have it land in the awarded
  /// list carrying that badge's real name and artwork. The coordinate
  /// already encodes the issuer, so this costs no extra relay round trip.
  static bool _isIssuedByBadgeOwner(Nip58BadgeAward award) {
    final coordinate = BadgeCoordinate.parse(award.definitionCoordinate);
    return coordinate != null && coordinate.pubkey == award.event.pubkey;
  }

  Future<Nip58ProfileBadges?> _latestProfileBadges(String pubkey) async {
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
    // NIP-58 treats legacy 30008/d=profile_badges as equivalent to 10008,
    // so resolve both encodings as one newest-wins profile badge list.
    final fromRelays = _newestParsedProfileBadges([
      ...results[0],
      ...results[1],
    ]);

    return _preferPublishedProfileBadges(pubkey, fromRelays);
  }

  Future<Map<String, Nip58ProfileBadges?>> _latestProfileBadgesForAuthors(
    List<String> pubkeys,
  ) async {
    if (pubkeys.isEmpty) return const {};
    final pubkeySet = pubkeys.toSet();
    final results = await _nostrClient.queryEvents([
      Filter(
        authors: pubkeys,
        kinds: [EventKind.profileBadges],
        limit: pubkeys.length * _profileBadgeEventsPerAuthorLimit,
      ),
      Filter(
        authors: pubkeys,
        kinds: [EventKind.badgeSet],
        d: ['profile_badges'],
        limit: pubkeys.length * _profileBadgeEventsPerAuthorLimit,
      ),
    ]);

    final byPubkey = <String, List<Event>>{};
    for (final event in results) {
      if (!pubkeySet.contains(event.pubkey)) continue;
      byPubkey.putIfAbsent(event.pubkey, () => []).add(event);
    }

    return {
      for (final pubkey in pubkeys)
        pubkey: _preferPublishedProfileBadges(
          pubkey,
          _newestParsedProfileBadges(byPubkey[pubkey] ?? const <Event>[]),
        ),
    };
  }

  Nip58ProfileBadges? _preferPublishedProfileBadges(
    String pubkey,
    Nip58ProfileBadges? fromRelays,
  ) {
    final published = _publishedProfileBadges;
    if (published == null || published.pubkey != pubkey) return fromRelays;
    // `>=` rather than `>`: `created_at` has one-second resolution, so an
    // accept and an undo in the same second tie, and the newest-wins sort
    // would fall through to comparing event ids — which would hand the
    // decision to a coin flip instead of to the write that just happened.
    if (fromRelays != null &&
        fromRelays.event.createdAt > published.badges.event.createdAt) {
      return fromRelays;
    }
    return published.badges;
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

    final sorted = events.toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    final fromRelay = sorted.isEmpty
        ? null
        : Nip58BadgeParser.parseDefinition(sorted.first);
    return _preferPublishedDefinition(coordinate, fromRelay);
  }

  /// Prefers a definition this repository published over a relay read that is
  /// not strictly newer.
  ///
  /// A genuinely newer definition — an edit made on another device — still
  /// wins, so this stops mattering as soon as the relay catches up.
  Nip58BadgeDefinition? _preferPublishedDefinition(
    String coordinate,
    Nip58BadgeDefinition? fromRelay,
  ) {
    final published = _publishedDefinitions[coordinate];
    if (published == null) return fromRelay;
    if (fromRelay != null &&
        fromRelay.event.createdAt > published.event.createdAt) {
      return fromRelay;
    }
    return published;
  }

  /// The current user's badge definitions, newest per identifier.
  ///
  /// Merges in anything this repository published that the relay is not
  /// serving yet, so a badge created or edited moments ago is already part
  /// of the list.
  Future<List<Nip58BadgeDefinition>> _ownDefinitions(
    String pubkey, {
    required int limit,
  }) async {
    final events = await _queryDefinitionsByAuthor(pubkey, limit: limit);
    final byCoordinate = {
      for (final definition in _newestDefinitionPerIdentifier(events))
        definition.coordinate: definition,
    };
    for (final published in _publishedDefinitions.values) {
      if (published.event.pubkey != pubkey) continue;
      byCoordinate[published.coordinate] = _preferPublishedDefinition(
        published.coordinate,
        byCoordinate[published.coordinate],
      )!;
    }
    return byCoordinate.values.toList(growable: false);
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
      tags
        ..add(['a', ref.definitionCoordinate])
        ..add([
          'e',
          ref.awardEventId,
          if (ref.awardRelay != null && ref.awardRelay!.isNotEmpty)
            ref.awardRelay!,
        ]);
    }

    final event = await _signAndPublish(
      kind: EventKind.profileBadges,
      label: 'profile badges',
      tags: tags,
    );

    final published = Nip58BadgeParser.parseProfileBadges(event);
    if (published != null) {
      _publishedProfileBadges = (pubkey: event.pubkey, badges: published);
    }
  }

  /// Signs and publishes an empty-content event, returning the signed event.
  ///
  /// Throws [StateError] when signing fails and [BadgePublishException] when
  /// no relay confirms the publish.
  Future<Event> _signAndPublish({
    required int kind,
    required String label,
    required List<List<String>> tags,
  }) async {
    final event = await _signEvent(kind: kind, content: '', tags: tags);
    if (event == null) {
      throw StateError('Could not sign $label event');
    }

    final outcome = await _nostrClient.publishEventAwaitOk(event);
    if (outcome.failed) {
      throw BadgePublishException(
        'Could not publish $label event: ${outcome.summary}',
        outcome: outcome,
      );
    }
    return event;
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
      ..sort((left, right) {
        final byCreatedAt = right.event.createdAt.compareTo(
          left.event.createdAt,
        );
        if (byCreatedAt != 0) return byCreatedAt;

        final byKind = (right.isLegacyProfileBadges ? 0 : 1).compareTo(
          left.isLegacyProfileBadges ? 0 : 1,
        );
        if (byKind != 0) return byKind;

        return left.event.id.compareTo(right.event.id);
      });
    return sorted.first;
  }

  static bool _containsBadgeCoordinate(
    Nip58ProfileBadges? profileBadges,
    Nip58BadgeAward award,
  ) {
    return _containsBadgeCoordinateValue(
      profileBadges,
      award.definitionCoordinate,
    );
  }

  static bool _containsBadgeCoordinateValue(
    Nip58ProfileBadges? profileBadges,
    String coordinate,
  ) {
    return profileBadges?.badges.any(
          (ref) => ref.definitionCoordinate == coordinate,
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
  final Map<String, Future<Map<String, Nip58ProfileBadges?>>>
  _profileBadgeChunks = {};
  final Map<String, Future<List<Nip58BadgeAward>>> _issuedAwards = {};

  Future<Nip58BadgeDefinition?> definition(
    String coordinate,
    Future<Nip58BadgeDefinition?> Function() load,
  ) => _definitions.putIfAbsent(coordinate, load);

  Future<Nip58ProfileBadges?> profileBadges(
    String pubkey,
    Future<Nip58ProfileBadges?> Function() load,
  ) => _profileBadges.putIfAbsent(pubkey, load);

  Future<Map<String, Nip58ProfileBadges?>> profileBadgeChunk(
    List<String> pubkeys,
    Future<Map<String, Nip58ProfileBadges?>> Function() load,
  ) {
    final key = pubkeys.join(',');
    return _profileBadgeChunks.putIfAbsent(key, load);
  }

  /// Awards authored by [pubkey]. Shared by the issued and created passes,
  /// which read the same `kind:8`-by-author query.
  Future<List<Nip58BadgeAward>> issuedAwards(
    String pubkey,
    Future<List<Nip58BadgeAward>> Function() load,
  ) => _issuedAwards.putIfAbsent(pubkey, load);
}

String _definitionNameFromCoordinate(String coordinate) {
  final parts = coordinate.split(':');
  if (parts.length < 3) return coordinate;
  return parts.sublist(2).join(':');
}
