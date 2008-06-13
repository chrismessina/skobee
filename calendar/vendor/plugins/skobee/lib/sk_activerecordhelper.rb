#MES- From C:\ruby\lib\ruby\gems\1.8\gems\actionpack-1.12.1\lib\action_view\helpers\active_record_helper.rb
module ActionView
  module Helpers
    module ActiveRecordHelper

      #MGS- override so we can change HTML
      def error_messages_for(object_name, options = {})
        options = options.symbolize_keys
        object = instance_variable_get("@#{object_name}")
        unless object.errors.empty?
          object.errors.full_messages.join('<br/><br/>')
        end
      end

    end
  end
end