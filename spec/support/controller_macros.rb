# frozen_string_literal: true

# controller spec でもN+1検知できるようにする
# https://github.com/flyerhzm/bullet/issues/120#issuecomment-64226287
module ControllerMacros
  module InstanceMethods
    if defined?(Bullet) # For CI against rails master
      %w[get post put patch delete options head].each do |method|
        define_method method do |*args, **kwargs|
          Bullet.profile do
            super(*args, **kwargs)
          end
        end
      end
    end
  end
end
