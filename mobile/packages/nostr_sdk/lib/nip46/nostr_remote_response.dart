import 'dart:convert';

import '../signer/nostr_signer.dart';
import '../utils/string_util.dart';

class NostrRemoteResponse {
  String id;

  String result;

  String? error;

  NostrRemoteResponse(this.id, this.result, {this.error});

  /// Whether this is a NIP-46 auth challenge: [result] is the literal
  /// `auth_url` marker and [error] carries the URL the user must visit to
  /// authenticate out-of-band. The signer answers later on the same request
  /// id. An `auth_url` marker without a URL is malformed and not a challenge.
  bool get isAuthChallenge =>
      result == 'auth_url' && error != null && error!.isNotEmpty;

  static Future<NostrRemoteResponse?> decrypt(
    String ciphertext,
    NostrSigner signer,
    String pubkey,
  ) async {
    var plaintext = await signer.nip44Decrypt(pubkey, ciphertext);
    if (StringUtil.isNotBlank(plaintext)) {
      // print("plaintext $plaintext");
      var jsonMap = jsonDecode(plaintext!);

      var id = jsonMap["id"];
      var result = jsonMap["result"];

      if (id != null && id is String && result != null && result is String) {
        return NostrRemoteResponse(id, result, error: jsonMap["error"]);
      }
    }

    return null;
  }

  Future<String?> encrypt(NostrSigner signer, String pubkey) async {
    Map<String, dynamic> jsonMap = {};
    jsonMap["id"] = id;
    jsonMap["result"] = result;
    if (StringUtil.isNotBlank(error)) {
      jsonMap["error"] = error;
    }

    var jsonStr = jsonEncode(jsonMap);
    return await signer.nip44Encrypt(pubkey, jsonStr);
  }

  @override
  String toString() {
    return "$id $result $error";
  }
}
