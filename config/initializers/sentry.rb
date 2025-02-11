Sentry.init do |config|
  config.dsn = ENV.fetch('SENTRY_DSN') { nil }
  config.breadcrumbs_logger = %i[active_support_logger http_logger]
  config.enabled_environments = %w[production]
  config.profiles_sample_rate = 1.0

  config.traces_sampler =
    lambda do |sampling_context|
      # if this is the continuation of a trace, just use that decision (rate controlled by the caller)
      next sampling_context[:parent_sampled] unless sampling_context[:parent_sampled].nil?

      # transaction_context is the transaction object in hash form
      # keep in mind that sampling happens right after the transaction is initialized
      # for example, at the beginning of the request
      transaction_context = sampling_context[:transaction_context]

      # transaction_context helps you sample transactions with more sophistication
      # for example, you can provide different sample rates based on the operation or name
      op = transaction_context[:op]
      transaction_name = transaction_context[:name]

      case op
      when /http/
        # for Rails applications, transaction_name would be the request's path (env["PATH_INFO"]) instead of "Controller#action"
        case transaction_name
        when /^(?:up|robots)/
          0.0
        else
          0.01
        end
      when /websocket/
        # https://github.com/getsentry/sentry-ruby/blob/master/sentry-rails/lib/sentry/rails/action_cable.rb
        0.01
      when /active_job/
        # https://github.com/getsentry/sentry-ruby/blob/master/sentry-rails/lib/sentry/rails/active_job.rb
        case transaction_name
        when /MailDeliveryJob/i
          0.0
        else
          0.01 # you may want to set a lower rate for background jobs if the number is large
        end
      else
        0.0 # ignore all other transactions
      end
    end
end

ActiveSupport::Notifications.subscribe("deprecation.rails") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  message = event.payload[:message]
  Sentry.capture_message(message, level: :warning)
end

ActiveSupport::Notifications.subscribe("deprecation.ruby") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  message = event.payload[:message]
  Sentry.capture_message(message, level: :warning)
end

