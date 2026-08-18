#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'

json_path, candidate_version = ARGV
unless json_path && candidate_version
  abort('usage: ios_store_version_preflight.rb <latest-app-store-build-json> <candidate-version>')
end

def numeric_version(value, label)
  unless value.is_a?(String) && value.match?(/\A\d+(?:\.\d+){0,2}\z/)
    abort("ERROR: invalid #{label} #{value.inspect}; expected one to three numeric components.")
  end

  value.split('.').map(&:to_i).fill(0, value.count('.') + 1...3)
end

payload = JSON.parse(File.read(json_path))
unless payload.is_a?(Hash)
  abort('ERROR: expected a JSON object from App Store Connect.')
end

approved_version = payload['version']
abort('ERROR: App Store Connect response is missing version.') unless approved_version

candidate_parts = numeric_version(candidate_version, 'candidate version')
approved_parts = numeric_version(approved_version, 'approved App Store version')

unless (candidate_parts <=> approved_parts) == 1
  abort(
    "ERROR: candidate version #{candidate_version} must be newer than approved App Store version " \
    "#{approved_version}. Bump mobile/pubspec.yaml before cutting a Shorebird release.",
  )
end

puts "Candidate version #{candidate_version} is newer than approved App Store version #{approved_version}."
