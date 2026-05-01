#!/usr/bin/env bash
# Fails CI if release-applicable native transport-security policies regress.
#
# Guards (all release-applicable on every build type):
#   • Android <base-config> cleartext must stay disabled.
#   • Android must not trust user-installed CAs.
#   • Android cleartext <domain-config> must list ONLY loopback hosts
#     (10.0.2.2, localhost, 127.0.0.1) — adding anything else requires an
#     explicit script update so the change is reviewed.
#   • iOS / macOS NSAllowsArbitraryLoads / NSAllowsArbitraryLoadsInWebContent
#     must stay false.
#   • iOS / macOS NSExceptionAllowsInsecureHTTPLoads must stay false (any
#     domain).
#
# Loopback addresses can't be redirected by a network attacker, so the
# Android <domain-config> + iOS/macOS NSAllowsLocalNetworking exemptions
# are considered safe.
#
# Requires: xmllint (libxml2-utils on Debian/Ubuntu; pre-installed on
# macOS and on GitHub Actions ubuntu-latest runners).
set -euo pipefail

if ! command -v xmllint >/dev/null 2>&1; then
  echo "❌ xmllint not found. Install libxml2-utils (apt) or libxml2 (brew)."
  exit 1
fi

fail=0

# ---------------------------------------------------------------------------
# Android
# ---------------------------------------------------------------------------
android_release="android/app/src/main/res/xml/network_security_config.xml"
if [ ! -f "$android_release" ]; then
  echo "❌ Missing $android_release."
  fail=1
else
  if ! xmllint --noout "$android_release" 2>/dev/null; then
    echo "❌ $android_release is not well-formed XML."
    xmllint --noout "$android_release" || true
    fail=1
  fi

  base_cleartext=$(xmllint --xpath 'string(//base-config/@cleartextTrafficPermitted)' "$android_release" 2>/dev/null || echo "")
  if [ "$base_cleartext" = "true" ]; then
    echo "❌ $android_release allows cleartext on <base-config>."
    fail=1
  fi

  user_ca_count=$(xmllint --xpath 'count(//certificates[@src="user"])' "$android_release" 2>/dev/null || echo "0")
  if [ "${user_ca_count:-0}" != "0" ]; then
    echo "❌ $android_release trusts user CAs ($user_ca_count <certificates src=\"user\"/> entries)."
    fail=1
  fi

  # Pin the cleartext domain-config to the exact loopback allowlist.
  # Any additions/removals must update this script in the same PR.
  expected_cleartext_domains="10.0.2.2 127.0.0.1 localhost"
  actual_cleartext_domains=$(
    xmllint --xpath '//domain-config[@cleartextTrafficPermitted="true"]/domain/text()' "$android_release" 2>/dev/null \
      | tr -s '[:space:]' '\n' \
      | sed '/^$/d' \
      | sort -u \
      | tr '\n' ' ' \
      | sed 's/ $//'
  )
  if [ "$actual_cleartext_domains" != "$expected_cleartext_domains" ]; then
    echo "❌ $android_release cleartext <domain-config> host list changed."
    echo "   expected: $expected_cleartext_domains"
    echo "   actual:   $actual_cleartext_domains"
    fail=1
  fi
fi

# ---------------------------------------------------------------------------
# iOS / macOS plists — same checks
# ---------------------------------------------------------------------------
check_ats_plist() {
  local plist="$1"
  if [ ! -f "$plist" ]; then
    echo "❌ Missing $plist."
    fail=1
    return
  fi

  if ! xmllint --noout "$plist" 2>/dev/null; then
    echo "❌ $plist is not well-formed XML."
    xmllint --noout "$plist" || true
    fail=1
  fi

  local arbitrary_count
  arbitrary_count=$(xmllint --xpath 'count(//key[text()="NSAllowsArbitraryLoads"]/following-sibling::*[1][self::true])' "$plist" 2>/dev/null || echo "0")
  if [ "${arbitrary_count:-0}" != "0" ]; then
    echo "❌ $plist sets NSAllowsArbitraryLoads=true."
    fail=1
  fi

  local web_count
  web_count=$(xmllint --xpath 'count(//key[text()="NSAllowsArbitraryLoadsInWebContent"]/following-sibling::*[1][self::true])' "$plist" 2>/dev/null || echo "0")
  if [ "${web_count:-0}" != "0" ]; then
    echo "❌ $plist sets NSAllowsArbitraryLoadsInWebContent=true."
    fail=1
  fi

  local insecure_count
  insecure_count=$(xmllint --xpath 'count(//key[text()="NSExceptionAllowsInsecureHTTPLoads"]/following-sibling::*[1][self::true])' "$plist" 2>/dev/null || echo "0")
  if [ "${insecure_count:-0}" != "0" ]; then
    echo "❌ $plist sets NSExceptionAllowsInsecureHTTPLoads=true ($insecure_count occurrences)."
    fail=1
  fi
}

# List every Info.plist that ships in the app bundle or any extension /
# widget. Add new entries here whenever a new target with its own plist is
# introduced so the guard's coverage stays explicit at a glance.
check_ats_plist "ios/Runner/Info.plist"
check_ats_plist "ios/NotificationServiceExtension/Info.plist"
check_ats_plist "macos/Runner/Info.plist"

if [ "$fail" -ne 0 ]; then
  echo
  echo "Release-applicable native transport-security policy regressed."
  echo "If a new exception is genuinely required, add a narrow"
  echo "<domain-config>/<NSExceptionDomains> entry, document why, and"
  echo "update this script with a justified allowance."
  exit 1
fi
