ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'database_cleaner/active_record'

require 'simplecov'

if ENV['CI']
  require 'coveralls'
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    Coveralls::SimpleCov::Formatter
  ])
  SimpleCov.start do
    add_filter '.bundle/'
  end
  Coveralls.wear!
else
  SimpleCov.start
end

Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.fixture_paths = [
    "spec/fixtures"
  ]
  config.infer_base_class_for_anonymous_controllers = false
  config.order = 'random'
  config.include FactoryBot::Syntax::Methods
  config.include ControllerMacros::InstanceMethods, :type => :controller
  config.include ActiveJob::TestHelper
  config.include ActiveSupport::Testing::TimeHelpers
  config.include ActionDispatch::TestProcess
  config.include ActiveSupport::Testing::FileFixtures

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.include AuthHelper, type: :controller
end
