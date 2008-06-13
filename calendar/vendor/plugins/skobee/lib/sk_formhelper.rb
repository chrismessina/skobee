#MES- From C:\ruby\lib\ruby\gems\1.8\gems\actionpack-1.12.1\lib\action_view\helpers\form_helper.rb
module ActionView
  module Helpers
    module FormHelper

      #MES- Display a select list that edits the indicated method on the indicated object.
      # Choices is a 2D array that looks like this:
      # [
      #   [value1, display_string1],
      #   [value2, display_string2]
      # ]
      def select_field(object, method, choices, html_options = {})
        current_value = self.instance_variable_get("@#{object}").send(method)
        options = ''
        choices.each do | item |
          options << option_tag(item[1], item[0], current_value.to_s == item[0].to_s)
        end
        #MGS- set the name and id
        html_options["name"] = "#{object}[#{method}]"
        html_options["id"] = "#{object}_#{method}"
        content_tag("select", options, html_options)
      end

      def option_tag(text, value, selected = false)
        "<option value='#{value}'#{selected ? '  selected=\'selected\'' : ''}>#{text}</option>"
      end

      #MES- Similar to select_field, but you just supply a name for the control, rather than
      # supplying an object name and member name to edit.
      def select_field_tag(name, current_value, choices, html_options = {})
        #MGS- force the name to be set to the name, no matter the html options
        html_options['name'] = name
        #MES- Set the ID to the name, if no ID was supplied
        if !html_options.has_key?('id')
          #MES- Replace '[' with '_' and ']' with '' because square brackets are not
          # allowed in IDs.
          html_options['id'] = name.sub(/[\[]/, '_').sub(/\]/, '')
        end

        options = ''
        choices.each do | item |
          options << option_tag(item[1], item[0], current_value.to_s == item[0].to_s)
        end
        #MGS- use this rails helper to build the select element
        content_tag("select", options, html_options)
      end
    end
  end
end
