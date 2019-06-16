#PaperTrail::Rails::Engine.eager_load!
PaperTrail.config.track_associations = true

module ActiveSupport
  class Deprecation
    module Reporting
      def warn(message = nil, callstack = nil)
        return if message.match(/touch_with_version/) || message.match(/counter caches/)  

        super
      end
    end
  end
end