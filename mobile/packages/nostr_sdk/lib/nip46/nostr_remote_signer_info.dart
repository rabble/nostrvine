import '../client_utils/keys.dart';
import '../nip19/nip19.dart';
import '../utils/string_util.dart';

/// NIP-46 remote signer info supporting both bunker:// and nostrconnect:// URLs.
///
/// bunker:// URLs are bunker-initiated: the bunker provides the URL and the
/// client connects to the bunker's pubkey.
///
/// nostrconnect:// URLs are client-initiated: the client generates the URL
/// containing its ephemeral pubkey and the bunker connects to the client.
class NostrRemoteSignerInfo {
  /// For bunker://, this is the bunker's pubkey.
  /// For nostrconnect://, this is initially empty and set after connection.
  String remoteSignerPubkey;

  List<String> relays;

  String? optionalSecret;

  // Client signer nsec, sometime need to save all info in one place, so nsec
  // should save as a par here.
  String? nsec;

  // User Pubkey, sometime need to save all info in one place, so nsec should
  // save as a par here.
  String? userPubkey;

  /// Whether this is a client-initiated (nostrconnect://) connection.
  /// If true, the client generated the URL and is waiting for the bunker.
  final bool isClientInitiated;

  /// For nostrconnect://, the client's ephemeral pubkey (hex).
  /// This is the pubkey in the nostrconnect:// URL that the bunker connects to.
  String? clientPubkey;

  /// App name to display in the bunker's approval dialog.
  final String? appName;

  /// App URL/icon for the bunker's approval dialog.
  final String? appUrl;

  /// App icon for the bunker's approval dialog.
  final String? appIcon;

  NostrRemoteSignerInfo({
    required this.remoteSignerPubkey,
    required this.relays,
    this.optionalSecret,
    this.nsec,
    this.userPubkey,
    this.isClientInitiated = false,
    this.clientPubkey,
    this.appName,
    this.appUrl,
    this.appIcon,
  });

  @override
  String toString() {
    Map<String, dynamic> pars = {};
    pars["relay"] = relays;
    pars["secret"] = optionalSecret;
    if (nsec != null) {
      pars["nsec"] = nsec;
    }
    if (userPubkey != null) {
      pars["userPubkey"] = userPubkey;
    }

    var uri = Uri(
      scheme: "bunker",
      host: remoteSignerPubkey,
      queryParameters: pars,
    );

    return uri.toString();
  }

  static bool isBunkerUrl(String? bunkerUrlText) {
    if (bunkerUrlText != null) {
      return bunkerUrlText.startsWith("bunker://");
    }

    return false;
  }

  /// Check if the URL is a nostrconnect:// URL (client-initiated).
  static bool isNostrConnectUrl(String? urlText) {
    if (urlText != null) {
      return urlText.startsWith("nostrconnect://");
    }
    return false;
  }

  /// Generate a new nostrconnect:// URL for client-initiated connection.
  ///
  /// Creates an ephemeral keypair and constructs a URL that can be displayed
  /// as a QR code or copied for the user's signer app.
  ///
  /// [relays] - Relays to use for the connection (required)
  /// [appName] - App name for bunker's approval dialog (optional)
  /// [appUrl] - App URL for bunker's approval dialog (optional)
  /// [appIcon] - App icon URL for bunker's approval dialog (optional)
  /// [permissions] - Requested permissions (optional, defaults to standard set)
  static NostrRemoteSignerInfo generateNostrConnectUrl({
    required List<String> relays,
    String? appName,
    String? appUrl,
    String? appIcon,
    String? permissions,
  }) {
    // Generate ephemeral keypair for this connection
    final privateKey = generatePrivateKey();
    final nsec = Nip19.encodePrivateKey(privateKey);
    final clientPubkey = getPublicKey(privateKey);

    // Generate a random secret for response validation
    final secret = getRandomHexString(8); // 8 bytes = 16 hex chars

    return NostrRemoteSignerInfo(
      remoteSignerPubkey: '', // Unknown until bunker responds
      relays: relays,
      optionalSecret: secret,
      nsec: nsec,
      isClientInitiated: true,
      clientPubkey: clientPubkey,
      appName: appName,
      appUrl: appUrl,
      appIcon: appIcon,
    );
  }

  /// Convert to a nostrconnect:// URL string.
  ///
  /// Format per NIP-46:
  /// `nostrconnect://<client-pubkey>?relay=<relay>&secret=<secret>`
  /// `&name=<app-name>&url=<app-url>&image=<app-icon>&perms=<permissions>`
  String toNostrConnectUrl({String? permissions, String? callback}) {
    if (clientPubkey == null || clientPubkey!.isEmpty) {
      throw StateError('clientPubkey is required for nostrconnect:// URLs');
    }

    if (optionalSecret == null || optionalSecret!.isEmpty) {
      throw StateError('secret is required for nostrconnect:// URLs');
    }

    // Build the URL manually to handle multiple relay params properly
    final buffer = StringBuffer('nostrconnect://$clientPubkey?');
    final params = <String>[];

    // Add relay params (can be multiple)
    for (final relay in relays) {
      params.add('relay=${Uri.encodeComponent(relay)}');
    }

    // Add secret (required per NIP-46)
    params.add('secret=${Uri.encodeComponent(optionalSecret!)}');

    // Add optional app metadata as separate params (per NIP-46 spec)
    if (appName != null && appName!.isNotEmpty) {
      params.add('name=${Uri.encodeComponent(appName!)}');
    }
    if (appUrl != null && appUrl!.isNotEmpty) {
      params.add('url=${Uri.encodeComponent(appUrl!)}');
    }
    if (appIcon != null && appIcon!.isNotEmpty) {
      params.add('image=${Uri.encodeComponent(appIcon!)}');
    }

    // Add permissions if specified
    final perms =
        permissions ??
        'sign_event:0,sign_event:1,sign_event:3,sign_event:6,sign_event:7,'
            'sign_event:34236,nip44_encrypt,nip44_decrypt';
    params.add('perms=${Uri.encodeComponent(perms)}');

    // Add callback URL scheme for signer app to redirect back
    if (callback != null && callback.isNotEmpty) {
      params.add('callback=${Uri.encodeComponent(callback)}');
    }

    buffer.write(params.join('&'));
    return buffer.toString();
  }

  static NostrRemoteSignerInfo parseBunkerUrl(
    String bunkerUrlText, {
    String? nsec,
  }) {
    var uri = Uri.parse(bunkerUrlText);

    var pars = uri.queryParametersAll;

    var remoteSignerPubkey = uri.host;

    var relays = pars["relay"];
    if (relays == null || relays.isEmpty) {
      throw Exception("relay parameter missing in bunker url");
    }

    // Validate that all relay URLs are valid WebSocket URLs
    for (final relay in relays) {
      if (!relay.startsWith('wss://') && !relay.startsWith('ws://')) {
        throw Exception("relay $relay should start with wss:// or ws://");
      }
    }

    var optionalSecrets = pars["secret"];
    String? optionalSecret;
    if (optionalSecrets != null && optionalSecrets.isNotEmpty) {
      optionalSecret = optionalSecrets.first;
    }

    if (StringUtil.isBlank(nsec)) {
      if (pars["nsec"] != null && pars["nsec"]!.isNotEmpty) {
        nsec = pars["nsec"]!.first;
      } else {
        nsec = Nip19.encodePrivateKey(generatePrivateKey());
      }
    }

    var userPubkeys = pars["userPubkey"];
    String? userPubkey;
    if (userPubkeys != null && userPubkeys.isNotEmpty) {
      userPubkey = userPubkeys.first;
    }

    return NostrRemoteSignerInfo(
      remoteSignerPubkey: remoteSignerPubkey,
      relays: relays,
      optionalSecret: optionalSecret,
      nsec: nsec!,
      userPubkey: userPubkey,
    );
  }
}
