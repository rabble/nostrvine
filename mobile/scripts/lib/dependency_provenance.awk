# Emit one line per non-hosted dependency source in a pubspec.lock.
#
# Sourced by check_dependency_provenance.sh (issue #3655 / #3363 AC3). Kept as a
# separate awk file — rather than inline in the shell script — so the detector
# can be exercised directly against fixtures from a Dart test, mirroring
# lib/dart_code_only.awk.
#
# Output (one per line, unsorted; the caller sorts):
#   git:<package>:PINNED     ref == resolved-ref and ref is a 40-hex SHA
#   git:<package>:MUTABLE    anything else (branch, tag, short ref, absent ref)
#   path:<package>:<path>    a path-sourced dependency
#
# Why ref vs resolved-ref: pub records both for a git source. A movable ref (a
# branch or tag) resolves to a SHA that differs from the ref as written, so the
# pair diverges. An immutable pin writes the same SHA in both. Verified against
# this repo's own history: before #6167 the c2pa_flutter entry read
# ref "0.0.3" / resolved-ref "847d0c..." — exactly the #3363 finding.
#
# `ref` absent entirely (no ref given, pub defaults to the default branch HEAD)
# must also be MUTABLE, so the default is set at package start, not on match.

BEGIN { pkg = ""; source = ""; ref = ""; resolved = ""; dpath = "" }

function flush() {
  if (pkg == "") return
  if (source == "git") {
    if (ref != "" && ref == resolved && ref ~ /^[0-9a-f]{40}$/) {
      print "git:" pkg ":PINNED"
    } else {
      print "git:" pkg ":MUTABLE"
    }
  } else if (source == "path") {
    print "path:" pkg ":" dpath
  }
}

# A package key is exactly two spaces of indent followed by name and a colon.
/^  [A-Za-z0-9_]+:[[:space:]]*$/ {
  flush()
  pkg = $0
  sub(/^  /, "", pkg)
  sub(/:[[:space:]]*$/, "", pkg)
  source = ""; ref = ""; resolved = ""; dpath = ""
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

END { flush() }

# Strip `<key>:`, surrounding whitespace and quotes from a scalar line.
function trim(line, key,   v) {
  v = line
  sub("^[[:space:]]*" key ":[[:space:]]*", "", v)
  gsub(/^["']|["'][[:space:]]*$/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
