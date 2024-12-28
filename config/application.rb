require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative "../lib/core_ext/warning"
# require_relative "../lib/middlewares/jp_only"
require_relative "../lib/middlewares/maintenance_mode"

module Gitfab2
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    config.time_zone = 'Tokyo'
    config.active_job.queue_adapter = :delayed_job
    config.active_support.cache_format_version = 7.0
    config.active_support.disable_to_s_conversion = true

    # config.middleware.insert 0, Middlewares::JpOnly
    config.middleware.insert 0, Middlewares::MaintenanceMode
  end
end
