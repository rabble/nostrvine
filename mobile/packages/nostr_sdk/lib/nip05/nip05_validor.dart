import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

class Nip05Validor {
  static final Map<String, int> _checking = {};

  /// Bounds a slow or hostile origin. Without it a stalled read hangs the
  /// caller for Dio's default (no timeout at all).
  static const Duration _timeout = Duration(seconds: 5);

  /// NIP-05 "Security Constraints": the `.well-known/nostr.json` endpoint MUST
  /// NOT return HTTP redirects, and fetchers MUST ignore any it returns.
  /// Following a 30x is a spurious-verify vector — a MITM or a misconfigured
  /// origin can bounce the lookup to a host that answers with an attacker's
  /// key. Dio's default `validateStatus` accepts 2xx only, so an unfollowed 3xx
  /// throws and [getPubkey] yields null rather than a redirected key.
  static var dio = Dio(
    BaseOptions(
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      followRedirects: false,
      maxRedirects: 0,
    ),
  );

  static Future<bool?> valid(String nip05Address, String pubkey) async {
    if (_checking[nip05Address] != null) {
      return null;
    }

    try {
      _checking[nip05Address] = 1;
      return await _doValid(nip05Address, pubkey);
    } finally {
      _checking.remove(nip05Address);
    }
  }

  static Future<bool> _doValid(String nip05Address, String pubkey) async {
    var remotePubkey = await getPubkey(nip05Address);
    if (remotePubkey == pubkey) {
      return true;
    }

    return false;
  }

  static Future<String?> getPubkey(String nip05Address) async {
    var name = "_";
    var address = nip05Address;
    var strs = nip05Address.split("@");
    if (strs.length > 1) {
      name = strs[0];
      address = strs[1];
    }

    var url = "https://$address/.well-known/nostr.json?name=$name";
    try {
      var response = await dio.get(url);
      if (response.data != null) {
        var map = response.data;
        if (map is String) {
          map = jsonDecode(response.data);
        }

        if (map is Map && map["names"] != null) {
          var dataPubkey = map["names"][name];
          if (dataPubkey != null && dataPubkey is String) {
            return dataPubkey;
          }
        }
      }
    } catch (e) {
      log('$e');
    }

    return null;
  }
}
