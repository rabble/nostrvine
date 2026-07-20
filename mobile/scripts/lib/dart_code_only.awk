# Emit Dart source with comments and string-literal bodies removed, so the
# purely textual design-system drift detectors (#6145) match real code only.
#
# Removed: line comments (`// …`, `/// …`), nestable block comments (`/* … */`,
# including multi-line), and the CONTENTS of string literals ('…', "…", '''…''',
# """…""", and r'…' raw forms). Interpolated expressions (`${…}`) are PRESERVED
# as code, since a token there is a real reference. Quote delimiters are kept so
# neighbouring tokens cannot fuse. Line count is preserved.
#
# Why not `sed 's|//.*||'`: that truncates at the `//` of a URL (`'https://…'`)
# or a path literal (`startsWith('//')`), silently DROPPING a real detector match
# later on the same line. Undercounting is the dangerous direction for a ceiling
# ratchet — it lets drift through and can fake a STALE win. This pass tracks
# string state, so a `//` inside a literal is never mistaken for a comment.
#
# Pinned by test/tools/dart_code_only_test.dart. Bash 3.2 / POSIX awk compatible.

BEGIN { blk = 0; instr = 0; israw = 0; q = ""; qlen = 0 }

{
  line = $0
  out = ""
  i = 1
  n = length(line)

  while (i <= n) {
    c = substr(line, i, 1)
    c2 = substr(line, i, 2)

    # --- inside a block comment: consume, honouring Dart's nesting ---
    if (blk > 0) {
      if (c2 == "*/") { blk--; i += 2 }
      else if (c2 == "/*") { blk++; i += 2 }
      else i++
      continue
    }

    # --- inside a string literal: drop the body, keep ${…} as code ---
    if (instr) {
      if (!israw && c == "\\") { i += 2; continue }
      if (c == "$" && substr(line, i + 1, 1) == "{") {
        out = out " "
        i += 2
        depth = 1
        while (i <= n) {
          ci = substr(line, i, 1)
          if (ci == "{") depth++
          else if (ci == "}") {
            depth--
            if (depth == 0) { i++; break }
          }
          out = out ci
          i++
        }
        out = out " "
        continue
      }
      if (substr(line, i, qlen) == q) { instr = 0; i += qlen; continue }
      i++
      continue
    }

    # --- ordinary code ---
    if (c2 == "//") break                       # rest of the line is a comment
    if (c2 == "/*") { blk++; i += 2; continue }

    if (c == "'" || c == "\"") {
      israw = (i > 1 && substr(line, i - 1, 1) == "r")
      if (substr(line, i, 3) == c c c) { q = c c c; qlen = 3 }
      else { q = c; qlen = 1 }
      instr = 1
      out = out q
      i += qlen
      continue
    }

    out = out c
    i++
  }

  print out
}
