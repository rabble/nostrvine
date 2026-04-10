import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:unified_logger/unified_logger.dart';

enum VerifierRequiredMethod {
  oauth('oauth'),
  publicProof('public_proof')
  ;

  const VerifierRequiredMethod(this.wireValue);

  final String wireValue;

  static VerifierRequiredMethod? fromWireValue(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    for (final method in values) {
      if (method.wireValue == value) {
        return method;
      }
    }

    return null;
  }
}

@immutable
class VerifierSocialHandleClaim {
  const VerifierSocialHandleClaim({
    required this.platform,
    required this.handle,
    this.preferredMethods = const <VerifierRequiredMethod>[],
  });

  final String platform;
  final String handle;
  final List<VerifierRequiredMethod> preferredMethods;

  Map<String, dynamic> toJson() {
    final encodedMethods = preferredMethods
        .map((method) => method.wireValue)
        .toList(growable: false);

    return <String, dynamic>{
      'platform': platform,
      'handle': handle,
      if (encodedMethods.isNotEmpty) 'method': encodedMethods.first,
      if (encodedMethods.length > 1) 'preferred_methods': encodedMethods,
    };
  }
}

@immutable
class VerifierClaimRequest {
  const VerifierClaimRequest({
    required this.pubkey,
    this.nip05,
    this.website,
    this.socialHandles = const <VerifierSocialHandleClaim>[],
    this.creatorBindingAssertionLabel,
    this.creatorBindingPayloadJson,
  });

  final String pubkey;
  final String? nip05;
  final String? website;
  final List<VerifierSocialHandleClaim> socialHandles;
  final String? creatorBindingAssertionLabel;
  final String? creatorBindingPayloadJson;

  Map<String, dynamic> toJson() {
    final requestedClaims = <String, dynamic>{
      if (nip05 != null) 'nip05': nip05,
      if (website != null) 'website': website,
      if (socialHandles.isNotEmpty)
        'social_handles': socialHandles
            .map((handle) => handle.toJson())
            .toList(growable: false),
    };

    return <String, dynamic>{
      'pubkey': pubkey,
      if (requestedClaims.isNotEmpty) 'requested_claims': requestedClaims,
      if (creatorBindingAssertionLabel != null ||
          creatorBindingPayloadJson != null)
        'creator_binding': <String, dynamic>{
          if (creatorBindingAssertionLabel != null)
            'assertion_label': creatorBindingAssertionLabel,
          if (creatorBindingPayloadJson != null)
            'payload_json': creatorBindingPayloadJson,
        },
    };
  }
}

@immutable
class VerifiedClaim {
  const VerifiedClaim({
    required this.type,
    required this.value,
    required this.method,
    this.platform,
    this.verifiedAt,
  });

  final String type;
  final String value;
  final String method;
  final String? platform;
  final DateTime? verifiedAt;

  factory VerifiedClaim.fromJson(Map<String, dynamic> json) {
    return VerifiedClaim(
      type: json['type']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      method: json['method']?.toString() ?? '',
      platform: json['platform']?.toString(),
      verifiedAt: _parseTimestamp(json['verified_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    'value': value,
    'method': method,
    if (platform != null) 'platform': platform,
    if (verifiedAt != null)
      'verified_at': verifiedAt!.toUtc().toIso8601String(),
  };
}

@immutable
class VerifierRequiredAction {
  const VerifierRequiredAction({
    required this.type,
    required this.value,
    this.platform,
    this.requiredMethod,
  });

  final String type;
  final String value;
  final String? platform;
  final VerifierRequiredMethod? requiredMethod;

  factory VerifierRequiredAction.fromJson(Map<String, dynamic> json) {
    return VerifierRequiredAction(
      type: json['type']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      platform: json['platform']?.toString(),
      requiredMethod: VerifierRequiredMethod.fromWireValue(
        json['required_method']?.toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    'value': value,
    if (platform != null) 'platform': platform,
    if (requiredMethod != null) 'required_method': requiredMethod!.wireValue,
  };
}

@immutable
class VerifierClaimBundle {
  const VerifierClaimBundle({
    required this.issuer,
    required this.status,
    this.verifiedClaims = const <VerifiedClaim>[],
    this.requiredActions = const <VerifierRequiredAction>[],
    this.identityAssertionLabel,
    this.identityAssertionPayload,
  });

  final String issuer;
  final String status;
  final List<VerifiedClaim> verifiedClaims;
  final List<VerifierRequiredAction> requiredActions;
  final String? identityAssertionLabel;
  final Map<String, dynamic>? identityAssertionPayload;

  factory VerifierClaimBundle.fromJson(Map<String, dynamic> json) {
    return VerifierClaimBundle(
      issuer: json['issuer']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      verifiedClaims: _decodeList(
        json['verified_claims'],
        VerifiedClaim.fromJson,
      ),
      requiredActions: _decodeList(
        json['required_actions'],
        VerifierRequiredAction.fromJson,
      ),
      identityAssertionLabel: json['identity_assertion_label']?.toString(),
      identityAssertionPayload: _decodeIdentityAssertionPayload(
        json['identity_assertion_payload'],
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'issuer': issuer,
    'status': status,
    if (verifiedClaims.isNotEmpty)
      'verified_claims': verifiedClaims
          .map((claim) => claim.toJson())
          .toList(growable: false),
    if (requiredActions.isNotEmpty)
      'required_actions': requiredActions
          .map((action) => action.toJson())
          .toList(growable: false),
    if (identityAssertionLabel != null)
      'identity_assertion_label': identityAssertionLabel,
    if (identityAssertionPayload != null)
      'identity_assertion_payload': identityAssertionPayload,
  };
}

class CawgVerifierClient {
  CawgVerifierClient({
    http.Client? httpClient,
    Uri? baseUri,
    Duration? timeout,
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _baseUri =
           baseUri ??
           Uri.parse(
             const String.fromEnvironment(
               'CAWG_VERIFIER_BASE_URL',
               defaultValue: 'https://verifier.divine.video',
             ),
           ),
       _timeout = timeout ?? const Duration(seconds: 8);

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Uri _baseUri;
  final Duration _timeout;

  Future<VerifierClaimBundle?> verifyClaims(
    VerifierClaimRequest request,
  ) async {
    final uri = _baseUri.resolve('/v1/claims/verify');

    try {
      final response = await _httpClient
          .post(
            uri,
            headers: const <String, String>{
              'accept': 'application/json',
              'content-type': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        Log.debug(
          'Verifier lookup failed with ${response.statusCode} from $uri',
          name: 'CawgVerifierClient',
          category: LogCategory.video,
        );
        return null;
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        Log.debug(
          'Verifier returned non-map payload from $uri',
          name: 'CawgVerifierClient',
          category: LogCategory.video,
        );
        return null;
      }

      return VerifierClaimBundle.fromJson(Map<String, dynamic>.from(payload));
    } on TimeoutException catch (error) {
      Log.debug(
        'Verifier request timed out for $uri: $error',
        name: 'CawgVerifierClient',
        category: LogCategory.video,
      );
      return null;
    } on http.ClientException catch (error) {
      Log.debug(
        'Verifier request failed for $uri: $error',
        name: 'CawgVerifierClient',
        category: LogCategory.video,
      );
      return null;
    } on FormatException catch (error) {
      Log.debug(
        'Verifier response parsing failed for $uri: $error',
        name: 'CawgVerifierClient',
        category: LogCategory.video,
      );
      return null;
    } catch (error) {
      Log.debug(
        'Verifier request failed for $uri: $error',
        name: 'CawgVerifierClient',
        category: LogCategory.video,
      );
      return null;
    }
  }

  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }
}

DateTime? _parseTimestamp(dynamic value) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(value.toString());
}

Map<String, dynamic>? _decodeIdentityAssertionPayload(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  if (value is String && value.isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  }

  return null;
}

List<T> _decodeList<T>(
  dynamic value,
  T Function(Map<String, dynamic> json) fromJson,
) {
  if (value is! List) {
    return <T>[];
  }

  return value
      .whereType<Map>()
      .map((item) => fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}
