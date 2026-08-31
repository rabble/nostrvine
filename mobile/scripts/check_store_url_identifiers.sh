#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ruby - \
  "$REPO_ROOT/mobile/android/app/build.gradle.kts" \
  "$REPO_ROOT/codemagic.yaml" \
  "$REPO_ROOT/mobile/packages/app_update_repository/lib/src/models/install_source.dart" <<'RUBY'
android_config_path, codemagic_path, download_urls_path = ARGV

android_config = File.read(android_config_path)
codemagic = File.read(codemagic_path)
download_urls = File.read(download_urls_path)

application_id = android_config.match(/^\s*applicationId\s*=\s*"([^"]+)"\s*$/)&.[](1)
app_store_id = codemagic.match(/^\s*APP_STORE_APP_ID=(\d+)\b/)&.[](1)
url_constants = download_urls
  .scan(/static const(?: String)?\s+(\w+)\s*=\s*'([^']+)'\s*;/m)
  .to_h

failures = []
failures << "#{android_config_path} must define applicationId." if application_id.nil?
failures << "#{codemagic_path} must define APP_STORE_APP_ID." if app_store_id.nil?

if application_id
  expected_play_store =
    "https://play.google.com/store/apps/details?id=#{application_id}"
  expected_zapstore = "https://zapstore.dev/apps/#{application_id}"

  unless url_constants['playStore'] == expected_play_store
    failures << "DownloadUrls.playStore must use Android applicationId #{application_id}."
  end
  unless url_constants['zapstore'] == expected_zapstore
    failures << "DownloadUrls.zapstore must use Android applicationId #{application_id}."
  end
end

if app_store_id
  expected_app_store = "https://apps.apple.com/app/id#{app_store_id}"
  unless url_constants['appStore'] == expected_app_store
    failures << "DownloadUrls.appStore must use App Store id #{app_store_id}."
  end
end

if failures.any?
  puts 'ERROR: update download URLs drifted from the shipped app identifiers.'
  failures.each { |failure| puts "  - #{failure}" }
  exit 1
end

puts 'Update download URLs match the shipped app identifiers.'
RUBY
