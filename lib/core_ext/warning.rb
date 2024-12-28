Warning[:deprecated] = true

module CoreExt
  module Warning
    alias_method :original_warn, :warn
   
    def warn(msg)
      return original_warn(msg) unless msg.include?("deprecated")
      ActiveSupport::Notifications.instrument "deprecation.ruby", message: msg
      original_warn(msg)
    end
  end
end

Warning.prepend(CoreExt::Warning)
