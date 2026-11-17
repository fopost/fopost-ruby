# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :development do
  gem 'minitest', '~> 5.20'
  gem 'rake', '~> 13.0'
  gem 'rubocop', '~> 1.60'
  gem 'rubocop-minitest', '~> 0.34'
  # Last lines that support Ruby 3.1, so one Gemfile.lock installs across the CI matrix.
  gem 'parallel', '< 2'
  gem 'prism', '< 2'
end
