import 'package:nostr_sdk/nip92/imeta_tag.dart';
import 'package:nostr_sdk/utils/path_type_util.dart';

import '../utils/string_util.dart';

class FileMetadata {
  String url;

  String m;

  // sha256, this field declare as required in NIP, but optional here.
  String? x;

  // original sha256, this field declare as required in NIP, but optional here.
  String? ox;

  String? size;

  String? dim;

  String? magnet;

  String? i;

  String? blurhash;

  String? thumb;

  String? image;

  String? summary;

  String? alt;

  List<String>? fallback;

  FileMetadata(
    this.url,
    this.m, {
    this.x,
    this.ox,
    this.size,
    this.dim,
    this.magnet,
    this.i,
    this.blurhash,
    this.thumb,
    this.image,
    this.summary,
    this.alt,
    this.fallback,
  });

  static FileMetadata? fromNIP92Tag(List tag) {
    if (tag.length > 1) {
      if (tag[0] != "imeta") {
        return null;
      }

      String? url;
      String? m;
      String? x;
      String? ox;
      String? size;
      String? dim;
      String? magnet;
      String? i;
      String? blurhash;
      String? thumb;
      String? image;
      String? summary;
      String? alt;
      List<String> fallback = [];

      parseImetaTag(List<String>.from(tag.map((e) => e.toString())), (
        key,
        value,
      ) {
        if (key == "url") {
          url = value;
        } else if (key == "m") {
          m = value;
        } else if (key == "x") {
          x = value;
        } else if (key == "ox") {
          ox = value;
        } else if (key == "size") {
          size = value;
        } else if (key == "dim") {
          dim = value;
        } else if (key == "magnet") {
          magnet = value;
        } else if (key == "i") {
          i = value;
        } else if (key == "blurhash") {
          blurhash = value;
        } else if (key == "thumb") {
          thumb = value;
        } else if (key == "image") {
          image = value;
        } else if (key == "summary") {
          summary = value;
        } else if (key == "alt") {
          alt = value;
        } else if (key == "fallback") {
          fallback.add(value);
        }
      });

      if (StringUtil.isBlank(m) && StringUtil.isNotBlank(url)) {
        var pathType = PathTypeUtil.getPathType(url!);
        if (pathType == "image") {
          m = "image/jpeg";
        }
      }

      if (StringUtil.isBlank(url) || StringUtil.isBlank(m)) {
        return null;
      }

      return FileMetadata(
        url!,
        m!,
        x: x,
        ox: ox,
        size: size,
        dim: dim,
        magnet: magnet,
        i: i,
        blurhash: blurhash,
        thumb: thumb,
        image: image,
        summary: summary,
        alt: alt,
        fallback: fallback,
      );
    }
    return null;
  }

  int? getImageWidth() {
    if (StringUtil.isNotBlank(dim)) {
      var strs = dim!.split("x");
      if (strs.isNotEmpty) {
        return int.tryParse(strs[0]);
      }
    }

    return null;
  }

  int? getImageHeight() {
    if (StringUtil.isNotBlank(dim)) {
      var strs = dim!.split("x");
      if (strs.length > 1) {
        return int.tryParse(strs[1]);
      }
    }

    return null;
  }
}
