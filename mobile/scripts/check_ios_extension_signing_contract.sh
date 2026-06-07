#!/usr/bin/env bash
set -euo pipefail

PROJECT_FILE="${1:-ios/Runner.xcodeproj/project.pbxproj}"
EXPECTED_BUNDLE_IDS="${IOS_EXTENSION_BUNDLE_IDS:-}"

if [ -z "$EXPECTED_BUNDLE_IDS" ]; then
  echo "ERROR: IOS_EXTENSION_BUNDLE_IDS must list every signed iOS app-extension bundle ID."
  exit 1
fi

ruby - "$PROJECT_FILE" "$EXPECTED_BUNDLE_IDS" <<'RUBY'
project_file, expected_raw = ARGV
project = File.read(project_file)

expected = expected_raw.split(/[,\s]+/).reject(&:empty?).sort

objects = project
  .scan(/^\t\t([A-Z0-9]+) \/\* ([^*]+) \*\/ = \{\n(.*?)^\t\t\};/m)
  .each_with_object({}) do |(id, name, body), result|
    result[id] = { name: name, body: body }
  end

target_blocks = objects.each_with_object([]) do |(target_id, object), targets|
  body = object[:body]
  next unless body.include?('isa = PBXNativeTarget;')
  next unless body.include?('productType = "com.apple.product-type.app-extension";')

  config_list_id = body.match(/buildConfigurationList = ([A-Z0-9]+) /)&.[](1)
  next unless config_list_id

  targets << [target_id, object[:name], config_list_id]
end

actual = target_blocks.flat_map do |_target_id, _target_name, config_list_id|
  config_list_body = objects[config_list_id]&.fetch(:body, nil)
  next [] unless config_list_body

  config_list_body.scan(/^\s*([A-Z0-9]+) \/\* [^*]+ \*\//).flat_map do |(config_id)|
    config_body = objects[config_id]&.fetch(:body, nil)
    next [] unless config_body

    bundle_id = config_body.match(/PRODUCT_BUNDLE_IDENTIFIER = ([^;\n]+);/)&.[](1)
    next [] unless bundle_id

    bundle_id.delete('"')
  end
end.uniq.sort

if actual.empty?
  puts "ERROR: no iOS app-extension bundle IDs were found in #{project_file}."
  exit 1
end

missing = actual - expected
stale = expected - actual

unless missing.empty? && stale.empty?
  puts "ERROR: iOS extension signing bundle IDs are out of sync."
  puts "Expected from IOS_EXTENSION_BUNDLE_IDS: #{expected.join(', ')}"
  puts "Actual app-extension targets: #{actual.join(', ')}"
  puts "Missing from IOS_EXTENSION_BUNDLE_IDS: #{missing.join(', ')}" unless missing.empty?
  puts "No matching app-extension target: #{stale.join(', ')}" unless stale.empty?
  puts "Every app extension also needs a matching App Store provisioning profile in Codemagic Code signing identities."
  exit 1
end

puts "iOS extension signing bundle IDs are in sync: #{actual.join(', ')}"
RUBY
