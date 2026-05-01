#!/usr/bin/env bash
# Fails CI if release-applicable native transport-security policies regress.
#
# Guards:
#   • Android base-config cleartext must stay disabled.
#   • Android must not trust user-installed CAs (any build type).
#   • Android cleartext <domain-config> must list ONLY loopback hosts
#     (10.0.2.2, localhost, 127.0.0.1) — adding anything else requires an
#     explicit script update so the change is reviewed.
#   • iOS NSAllowsArbitraryLoadsInWebContent must stay false.
#   • iOS NSExceptionAllowsInsecureHTTPLoads must stay false (any domain).
#
# Loopback addresses can't be redirected by a network attacker, so the
# Android <domain-config> + iOS NSAllowsLocalNetworking exemptions are
# considered safe.
set -euo pipefail

fail=0

android_release="android/app/src/main/res/xml/network_security_config.xml"
if [ ! -f "$android_release" ]; then
  echo "❌ Missing $android_release."
  fail=1
else
  if grep -qE '<base-config[^>]*cleartextTrafficPermitted="true"' "$android_release"; then
    echo "❌ $android_release allows cleartext on <base-config>."
    fail=1
  fi
  if grep -qE '<certificates[^>]*src="user"' "$android_release"; then
    echo "❌ $android_release trusts user CAs (<certificates src=\"user\"/>)."
    fail=1
  fi

  # Pin the cleartext domain-config to the exact loopback allowlist.
  # Any additions/removals must update this script in the same PR.
  expected_cleartext_domains="10.0.2.2 127.0.0.1 localhost"
  actual_cleartext_domains=$(
    awk '
      /<domain-config[^>]*cleartextTrafficPermitted="true"/ { flag=1; next }
      /<\/domain-config>/                                   { flag=0; next }
      flag
    ' "$android_release" \
      | grep -oE '>[^<]+<' \
      | tr -d '<>' \
      | sort -u \
      | xargs
  )
  if [ "$actual_cleartext_domains" != "$expected_cleartext_domains" ]; then
    echo "❌ $android_release cleartext <domain-config> host list changed."
    echo "   expected: $expected_cleartext_domains"
    echo "   actual:   $actual_cleartext_domains"
    fail=1
  fi
fi

ios_plist="ios/Runner/Info.plist"
if [ ! -f "$ios_plist" ]; then
  echo "❌ Missing $ios_plist."
  fail=1
else
  if grep -A1 '<key>NSAllowsArbitraryLoadsInWebContent</key>' "$ios_plist" | grep -q '<true/>'; then
    echo "❌ $ios_plist sets NSAllowsArbitraryLoadsInWebContent=true."
    fail=1
  fi
  if grep -A1 '<key>NSExceptionAllowsInsecureHTTPLoads</key>' "$ios_plist" | grep -q '<true/>'; then
    echo "❌ $ios_plist sets NSExceptionAllowsInsecureHTTPLoads=true."
    fail=1
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo
  echo "Release-applicable native transport-security policy regressed."
  echo "If a new exception is genuinely required, add a narrow"
  echo "<domain-config>/<NSExceptionDomains> entry, document why, and"
  echo "update this script with a justified allowance."
  exit 1
fi
