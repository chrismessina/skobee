#MES- From C:\ruby\lib\ruby\gems\1.8\gems\actionpack-1.12.1\lib\action_view\helpers\text_helper.rb
module ActionView
  module Helpers #:nodoc:


    #MGS- overriding this function from default rails as we don't want to wrap
    # the entire text block in a <p> tag


    # Provides a set of methods for working with text strings that can help unburden the level of inline Ruby code in the
    # templates. In the example below we iterate over a collection of posts provided to the template and print each title
    # after making sure it doesn't run longer than 20 characters:
    #   <% for post in @posts %>
    #     Title: <%= truncate(post.title, 20) %>
    #   <% end %>
    module TextHelper
      #MGS- override of built-in rails auto-link function
      AUTO_LINK_RE = /
                        (                       # leading text
                          <\w+.*?>|             #   leading HTML tag, or
                          [^=!:'"\/]|           #   leading punctuation, or
                          ^                     #   beginning of line
                        )
                        (
                          (?:http[s]?:\/\/)|    # protocol spec, or
                          (?:www\.)             # www.*
                        )
                        (
                          ([\w]+:?[=?~@&\/.-]*?)*    # url segment MGS- used to be: ([\w]+:?[=?&\/.-]?)*
                          \w+[\/]?              # url tail
                          (?:\#\w*)?            # trailing anchor
                        )
                        ([[:punct:]]|\s|<|$)    # trailing text
                       /x

      # Returns +text+ transformed into HTML using very simple formatting rules
      # Surrounds paragraphs with <tt>&lt;p&gt;</tt> tags, and converts line breaks into <tt>&lt;br /&gt;</tt>
      # Two consecutive newlines(<tt>\n\n</tt>) are considered as a paragraph, one newline (<tt>\n</tt>) is
      # considered a linebreak, three or more consecutive newlines are turned into two newlines
      def simple_format(text)
        text.gsub!(/(\r\n|\n|\r)/, "\n") # lets make them newlines crossplatform
        text.gsub!(/\n\n+/, "\n\n") # zap dupes
        text.gsub!(/\n\n/, '</p>\0<p>') # turn two newlines into paragraph
        text.gsub!(/([^\n])(\n)([^\n])/, '\1\2<br />\3') # turn single newline into <br />

        #MGS- don't want everything wrapped in a <p> tag
        #content_tag("p", text)
        return text
      end
    end
  end
end