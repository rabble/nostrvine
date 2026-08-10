# Emit one line per dependency source in a pubspec.lock that does not resolve
# from pub.dev.
#
# Sourced by check_dependency_provenance.sh (issue #3655 / #3363 AC3). Kept as a
# separate awk file — rather than inline in the shell script — so the detector
# can be exercised directly against fixtures from a Dart test, mirroring
# lib/dart_code_only.awk.
#
# Output (one per line, unsorted; the caller sorts):
#   git:<package>:<url>:PINNED     ref == resolved-ref and ref is a 40-hex SHA
#   git:<package>:<url>:MUTABLE    anything else (branch, tag, short ref, absent ref)
#   path:<package>:<path>          a path-sourced dependency
#   hosted:<package>:<url>         a hosted dependency from a non-pub.dev registry
#
# Why ref vs resolved-ref: pub records both for a git source. A movable ref (a
# branch or tag) resolves to a SHA that differs from the ref as written, so the
# pair diverges. An immutable pin writes the same SHA in both. Verified against
# this repo's own history: before #6167 the c2pa_flutter entry read
# ref "0.0.3" / resolved-ref "847d0c..." — exactly the #3363 finding.
#
# `ref` absent entirely (no ref given, pub defaults to the default branch HEAD)
# must also be MUTABLE, so the default is set at package start, not on match.

BEGIN { pkg = ""; source = ""; ref = ""; resolved = ""; dpath = ""; url = "" }

function flush() {
  if (pkg == "") return
  if (source == "git") {
    if (ref != "" && ref == resolved && ref ~ /^[0-9a-f]{40}$/) {
      print "git:" pkg ":" url ":PINNED"
    } else {
      print "git:" pkg ":" url ":MUTABLE"
    }
  } else if (source == "path") {
    print "path:" pkg ":" dpath
  } else if (source == "hosted" && url != "" && url != "https://pub.dev") {
    print "hosted:" pkg ":" url
  }
}

# A package key is exactly two spaces of indent followed by name and a colon.
/^  [A-Za-z0-9_]+:[[:space:]]*$/ {
  flush()
  pkg = $0
  sub(/^  /, "", pkg)
  sub(/:[[:space:]]*$/, "", pkg)
  source = ""; ref = ""; resolved = ""; dpath = ""; url = ""
  next
}

# Any line at or above the package key's indent that is not a package key ends
# the packages block (e.g. the trailing `sdks:` map).
/^[A-Za-z]/ { flush(); pkg = ""; next }

pkg == "" { next }

/^    source:[[:space:]]/       { source = trim($0, "source"); next }
/^      ref:[[:space:]]/        { ref = trim($0, "ref"); next }
/^      resolved-ref:[[:space:]]/ { resolved = trim($0, "resolved-ref"); next }
/^      path:[[:space:]]/       { dpath = trim($0, "path"); next }
/^      url:[[:space:]]/        { url = trim($0, "url"); next }

END { flush() }

# Strip `<key>:`, surrounding whitespace and quotes from a scalar line.
function trim(line, key,   v) {
  v = line
  sub("^[[:space:]]*" key ":[[:space:]]*", "", v)
  gsub(/^["']|["'][[:space:]]*$/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
