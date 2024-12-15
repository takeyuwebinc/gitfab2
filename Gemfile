source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.6.6'

gem 'rails', '~> 6.0.3'

gem 'active_decorator'
gem 'acts_as_list'
gem 'bcrypt', require: false
gem 'bootstrap'
gem 'cancancan'
gem 'carrierwave'
gem 'friendly_id'
gem 'jb'
gem 'jbuilder'
gem 'kaminari'
gem 'mini_magick'
gem 'mysql2'
gem 'nested_form'
gem 'nokogiri'
gem 'omniauth-facebook'
gem 'omniauth-github'
gem 'omniauth-google-oauth2'
gem 'rails_autolink'
gem 'sanitize'
gem 'slack-notifier'
gem 'slim-rails'
gem 'sprockets-commoner'
gem 'truncate_html'
gem 'rubyzip'
gem 'whenever', require: false
gem 'delayed_job_active_record'
gem "maxmind-db"

# Frontend
gem 'autoprefixer-rails'
gem 'coffee-rails'
gem 'jquery-rails'
gem 'sass-rails'
gem 'uglifier'
gem 'sprockets', '3.7.2'

gem 'stl', github: 'oshimaryo/stl-ruby'
gem 'stl2gif', github: 'takeyuwebinc/stl2gif', branch: 'develop'
gem 'mathn' # Used in geometry gem in stl gem

gem "sentry-rails"
gem 'activerecord-import'

group :development, :test do
  gem 'bullet'
  gem 'factory_bot_rails'
  gem 'rspec-rails'
  gem 'rubocop', require: false
  gem 'spring'
  gem 'spring-commands-rspec'
  gem 'faker'
end

group :development do
  gem 'annotate'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'letter_opener_web'
  gem 'meta_request'
  gem 'puma'
  gem 'rack-mini-profiler', require: false
  gem 'web-console'
  gem 'listen'
end

group :test do
  gem 'coveralls', require: false
  gem 'database_rewinder'
  gem 'rails-controller-testing'
  gem 'simplecov', require: false
end

group :production, :staging do
  gem 'unicorn'
  gem 'daemons' # https://github.com/collectiveidea/delayed_job/blob/740bbca3ee52ad3c8938f2ea673bb3d778c33bd5/lib/delayed/command.rb#L5
end
