#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'
require 'optparse'

HEX_SHA = /\A[0-9a-f]{40}\z/
RELEASE_VERSION = /\A[0-9A-Za-z][0-9A-Za-z._+-]*\z/
PATCHABLE_PLATFORMS = %w[android ios].freeze
BLOCKED_ROOTS = %w[android ios macos web assets scripts shaders].freeze
BLOCKED_FILES = %w[pubspec.yaml pubspec.lock shorebird.yaml].freeze
BLOCKED_PACKAGE_PATH = %r{\Apackages/[^/]+/(?:android|assets|shaders|darwin|ios|macos)(?:/|\z)}
BLOCKED_PACKAGE_PUBSPEC = %r{\Apackages/[^/]+/pubspec\.yaml\z}

def abort_with(message)
  warn("ERROR: #{message}")
  exit 1
end

def git(*arguments)
  stdout, stderr, status = Open3.capture3('git', *arguments)
  abort_with("git #{arguments.join(' ')} failed: #{stderr.strip}") unless status.success?

  stdout.strip
end

def blocked_path?(path)
  BLOCKED_FILES.include?(path) ||
    BLOCKED_ROOTS.any? { |root| path == root || path.start_with?("#{root}/") } ||
    path.match?(BLOCKED_PACKAGE_PATH) ||
    path.match?(BLOCKED_PACKAGE_PUBSPEC)
end

options = {}
OptionParser.new do |parser|
  parser.on('--baseline VALUE') { |value| options[:baseline] = value }
  parser.on('--platform VALUE') { |value| options[:platform] = value }
  parser.on('--release-version VALUE') { |value| options[:release_version] = value }
  parser.on('--branch VALUE') { |value| options[:branch] = value }
  parser.on('--identity-only') { options[:identity_only] = true }
end.parse!

missing = %i[baseline platform release_version branch].select do |name|
  options.fetch(name, '').empty?
end
abort_with("missing option(s): #{missing.map { |name| "--#{name.to_s.tr('_', '-')}" }.join(', ')}") unless missing.empty?

baseline = options[:baseline]
platform = options[:platform]
release_version = options[:release_version]
branch = options[:branch]

abort_with('baseline must be a full lowercase commit SHA') unless baseline.match?(HEX_SHA)
abort_with('platform must be android or ios') unless PATCHABLE_PLATFORMS.include?(platform)
abort_with('release version contains characters that are unsafe in a branch name') unless release_version.match?(RELEASE_VERSION)

expected_branch = "shorebird-patch/#{platform}/#{release_version}"
unless branch == expected_branch
  abort_with("patch branch must be exactly #{expected_branch.inspect} for this release")
end
exit 0 if options[:identity_only]

unless system('git', 'merge-base', '--is-ancestor', baseline, 'HEAD', out: File::NULL, err: File::NULL)
  abort_with('recorded patch baseline is not an ancestor of the patch source')
end

range = "#{baseline}..HEAD"
merge_commits = git('rev-list', '--merges', range).lines(chomp: true)
abort_with('patch source contains merge commits; use a linear backport history') unless merge_commits.empty?

# git diff --name-only prints repository-root-relative paths regardless of the
# current directory, while the patch workflows run with working_directory
# mobile/. Normalize to mobile-relative so the blocked-path checks below match
# in both layouts.
changed_paths = git('diff', '--name-only', range).lines(chomp: true).map do |path|
  path.sub(%r{\Amobile/}, '')
end
blocked_paths = changed_paths.select { |path| blocked_path?(path) }
unless blocked_paths.empty?
  warn('ERROR: refusing to patch: this diff contains native, asset, dependency, build script, or Shorebird configuration changes.')
  warn
  blocked_paths.each { |path| warn(path) }
  warn
  abort_with('cut a normal store release instead of a Shorebird patch')
end

dart_paths = changed_paths.select { |path| path.end_with?('.dart') }
abort_with('no Dart changes found between the release baseline and patch source') if dart_paths.empty?

puts("Verified patch branch: #{branch}")
puts("Patch source commits after release baseline #{baseline}:")
puts(git('log', '--oneline', range))
puts
puts('Dart files changed by the complete patch:')
dart_paths.each { |path| puts(path) }
