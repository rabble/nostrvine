#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'

json_path, platform, release_version = ARGV
unless json_path && platform && release_version
  abort('usage: shorebird_release_preflight.rb <releases-json> <platform> <release-version>')
end

payload = JSON.parse(File.read(json_path))

unless payload['status'] == 'success'
  error = payload['error'] || {}
  code = error['code'] || 'unknown_error'
  message = error['message'] || 'no error message'
  abort("ERROR: Shorebird releases list failed (#{code}): #{message}")
end

data = payload['data']
releases = data && data['releases']
unless releases.is_a?(Array)
  abort('ERROR: Shorebird releases list JSON is missing releases array at data.releases.')
end

release = releases.find { |item| item['version'] == release_version }
platform_statuses = release && release['platform_statuses']
status = platform_statuses[platform] if platform_statuses.is_a?(Hash)

if status == 'active'
  abort(
    "ERROR: #{platform} Shorebird release #{release_version} already exists and is active.\n" \
    'Bump the build number/version or delete the failed Shorebird release before retrying.',
  )
end

puts "No existing active Shorebird #{platform} release found for #{release_version}; continuing."
