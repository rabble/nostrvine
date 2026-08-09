#!/usr/bin/env bash
set -euo pipefail

PROJECT_FILE="${1:-ios/Runner.xcodeproj/project.pbxproj}"
APP_VERSION_XCCONFIG="${2:-ios/Flutter/AppVersion.xcconfig}"

if [ ! -f "$PROJECT_FILE" ]; then
  echo "ERROR: missing $PROJECT_FILE."
  exit 1
fi

if [ ! -f "$APP_VERSION_XCCONFIG" ]; then
  echo "ERROR: missing $APP_VERSION_XCCONFIG."
  exit 1
fi

ruby - "$PROJECT_FILE" "$APP_VERSION_XCCONFIG" <<'RUBY'
project_file, app_version_xcconfig = ARGV
project = File.read(project_file)
xcconfig = File.read(app_version_xcconfig)

failures = []

unless xcconfig.match?(/^\s*#include\?\s+"Generated\.xcconfig"\s*$/)
  failures << "#{app_version_xcconfig} must optionally include Generated.xcconfig."
end

unless xcconfig.match?(/^\s*MARKETING_VERSION\s*=\s*\$\(FLUTTER_BUILD_NAME\)\s*$/)
  failures << "#{app_version_xcconfig} must set MARKETING_VERSION from FLUTTER_BUILD_NAME."
end

unless xcconfig.match?(/^\s*CURRENT_PROJECT_VERSION\s*=\s*\$\(FLUTTER_BUILD_NUMBER\)\s*$/)
  failures << "#{app_version_xcconfig} must set CURRENT_PROJECT_VERSION from FLUTTER_BUILD_NUMBER."
end

objects = project
  .scan(/^\t\t([A-Z0-9]+) \/\* ([^*]+) \*\/ = \{\n(.*?)^\t\t\};/m)
  .each_with_object({}) do |(id, name, body), result|
    result[id] = { name: name, body: body }
  end

app_version_ref_ids = project
  .scan(/^\t\t([A-Z0-9]+) \/\* AppVersion\.xcconfig \*\/ = \{[^}]*path = Flutter\/AppVersion\.xcconfig;[^}]*\};/)
  .flatten

if app_version_ref_ids.empty?
  failures << 'Runner.xcodeproj must reference Flutter/AppVersion.xcconfig.'
end

runner_target = objects.find do |_id, object|
  object[:name] == 'Runner' &&
    object[:body].include?('isa = PBXNativeTarget;') &&
    object[:body].include?('productType = "com.apple.product-type.application";')
end

if runner_target.nil?
  failures << 'Runner application target was not found.'
else
  _target_id, target = runner_target
  config_list_id = target[:body].match(/buildConfigurationList = ([A-Z0-9]+) /)&.[](1)
  config_ids = objects[config_list_id]&.fetch(:body, '')&.scan(/^\s*([A-Z0-9]+) \/\* (Debug|Release|Profile) \*\//)&.map(&:first) || []

  config_ids.each do |config_id|
    config = objects[config_id]
    next unless config

    body = config[:body]
    config_name = config[:name]
    marketing_version = body.match(/MARKETING_VERSION = ([^;\n]+);/)&.[](1)
    current_project_version = body.match(/CURRENT_PROJECT_VERSION = ([^;\n]+);/)&.[](1)

    unless marketing_version == '"$(FLUTTER_BUILD_NAME)"'
      failures << "Runner #{config_name} MARKETING_VERSION must be $(FLUTTER_BUILD_NAME), got #{marketing_version || 'nil'}."
    end

    unless current_project_version == '"$(FLUTTER_BUILD_NUMBER)"'
      failures << "Runner #{config_name} CURRENT_PROJECT_VERSION must be $(FLUTTER_BUILD_NUMBER), got #{current_project_version || 'nil'}."
    end
  end
end

extension_targets = objects.select do |_id, object|
  object[:body].include?('isa = PBXNativeTarget;') &&
    object[:body].include?('productType = "com.apple.product-type.app-extension";')
end

if extension_targets.empty?
  failures << 'No iOS app-extension targets were found.'
end

extension_targets.each do |_target_id, target|
  config_list_id = target[:body].match(/buildConfigurationList = ([A-Z0-9]+) /)&.[](1)
  config_ids = objects[config_list_id]&.fetch(:body, '')&.scan(/^\s*([A-Z0-9]+) \/\* (Debug|Release|Profile) \*\//)&.map(&:first) || []

  config_ids.each do |config_id|
    config = objects[config_id]
    next unless config

    body = config[:body]
    config_name = config[:name]
    base_config_id = body.match(/baseConfigurationReference = ([A-Z0-9]+) /)&.[](1)

    unless app_version_ref_ids.include?(base_config_id)
      failures << "#{target[:name]} #{config_name} must use AppVersion.xcconfig as its base configuration."
    end

    if body.match?(/MARKETING_VERSION\s*=/)
      failures << "#{target[:name]} #{config_name} must inherit MARKETING_VERSION instead of setting it inline."
    end

    if body.match?(/CURRENT_PROJECT_VERSION\s*=/)
      failures << "#{target[:name]} #{config_name} must inherit CURRENT_PROJECT_VERSION instead of setting it inline."
    end
  end
end

if failures.any?
  puts 'ERROR: iOS shipping target version configuration drifted.'
  failures.each { |failure| puts "  - #{failure}" }
  exit 1
end

puts 'iOS shipping target versions derive from Flutter build variables.'
RUBY
