class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  before_perform do |job|
    Sentry.set_extras(
      job_class: job.class.name,
      job_arguments: job.arguments.to_param
    )
  end

  # TODO: Rails 7.1 になったら消す ActiveSupport::ErrorReporter でサブスクライブされているため
  rescue_from Exception do |exception|
    Sentry.capture_exception(exception)
    raise exception
  end
end
