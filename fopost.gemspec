# frozen_string_literal: true

require_relative 'lib/fopost/version'

Gem::Specification.new do |spec|
  spec.name = 'fopost'
  spec.version = Fopost::VERSION
  spec.authors = ['FoPost', 'Porter Bridge, LLC']
  spec.license = 'MIT'

  spec.summary = 'Official Ruby SDK for the FoPost API.'
  spec.description = 'Official Ruby SDK for the FoPost API. Schedule and publish to +30 social ' \
                     'platforms from your code.'
  spec.homepage = 'https://fopost.com'

  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => 'https://github.com/fopost/fopost-ruby',
    'bug_tracker_uri' => 'https://github.com/fopost/fopost-ruby/issues',
    'documentation_uri' => 'https://fopost.com/docs',
    'changelog_uri' => 'https://github.com/fopost/fopost-ruby/blob/main/CHANGELOG.md',
    'rubygems_mfa_required' => 'true'
  }

  spec.required_ruby_version = '>= 3.1'

  spec.files = Dir['lib/**/*.rb'] + %w[LICENSE README.md CHANGELOG.md]
  spec.require_paths = ['lib']

  # No runtime dependencies on purpose: the SDK talks over net/http from the
  # standard library, so it drops into any app without a version conflict.
end
