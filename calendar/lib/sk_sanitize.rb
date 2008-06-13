module Sanitize

  #MGS- takes a string and some allowed HTML tags and attributes
  # and sanitizes the string for all tags/attributes besides the
  # allowed attributes
  def sanitize_text( html, okTags='a href, b, i, u, img src width height alt title' )
    # no closing tag necessary for these
    soloTags = ["br","hr","img"]

    #MGS- exit out if we were passed in a blank string
    return "" if html.blank?

    # Build hash of allowed tags with allowed attributes
    tags = okTags.downcase().split(',').collect!{ |s| s.split(' ') }
    allowed = Hash.new
    tags.each do |s|
      key = s.shift
      allowed[key] = s
    end

    # Analyze all <> elements
    stack = Array.new
    result = html.gsub( /(<.*?>)/m ) do | element |
      if element =~ /\A<\/(\w+)/ then
        #MGS- closing tag: </tag>
        tag = $1.downcase
        if allowed.include?(tag) && stack.include?(tag) then
          # If allowed and on the stack
          # Then pop down the stack
          top = stack.pop
          out = "</#{top}>"
          until top == tag do
            top = stack.pop
            out << "</#{top}>"
          end
          out
        else
          #MGS- encode a closing tag that is not allowed
          h(element)
        end
      elsif element =~ /\A<(\w+)\s*\/>/
        #MGS- solo tag <tag />
        tag = $1.downcase
        if allowed.include?(tag) then
          "<#{tag} />"
        end
      elsif element =~ /\A<(\w+)/ then
        #MGS- opening tag <tag ...>
        tag = $1.downcase
        if allowed.include?(tag) then
          if ! soloTags.include?(tag) then
            stack.push(tag)
          end
          if allowed[tag].length == 0 then
            # no allowed attributes
            "<#{tag}>"
          else
            # allowed attributes?
            out = "<#{tag}"
            #MGS- attributes must be in quotations
            while ( $' =~ /(\w+)=("[^"]+")/ )
              attr = $1.downcase
              valu = $2
              if allowed[tag].include?(attr) then
                out << " #{attr}=#{valu}"
              end
            end
            #MGS- check to see if its a solo tag, if it is, end it with some xhtml quality close
            out << (soloTags.include?(tag) ? "/>" : ">")
          end
        else
          #MGS- encode anopening tag that is not allowed
          h(element)
        end
      end
    end

    #MGS- eat up unmatched leading >
    while result.sub!(/\A([^<]*)>/m) { $1 + "&gt;" } do end

    #MGS- eat up unmatched trailing <
    while result.sub!(/<([^>]*)\Z/m) { "&lt;" + $1 } do end

    # clean up the stack
    if stack.length > 0 then
      result << "</#{stack.reverse.join('></')}>"
    end

    result
  end

end




#MGS- here is the original source, if we need to refer back to it
# the main thing I changed was to not throw away < and > tags, but
# to html encode them
#
# $Id: sanitize.rb 3 2005-04-05 12:51:14Z dwight $
#
# Copyright (c) 2005 Dwight Shih
# A derived work of the Perl version:
# Copyright (c) 2002 Brad Choate, bradchoate.com
#
# Permission is hereby granted, free of charge, to
# any person obtaining a copy of this software and
# associated documentation files (the "Software"), to
# deal in the Software without restriction, including
# without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to
# whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission
# notice shall be included in all copies or
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY
# OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
# LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
# OR OTHER LIABILITY, WHETHER IN AN ACTION OF
# CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
# OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# from: http://blog.ideoplex.com/2005/03/17.html
#def sanitize( html, okTags='a href, b, br, i, p' )
#  # no closing tag necessary for these
#  soloTags = ["br","hr"]
#
#  # Build hash of allowed tags with allowed attributes
#  tags = okTags.downcase().split(',').collect!{ |s| s.split(' ') }
#  allowed = Hash.new
#  tags.each do |s|
#    key = s.shift
#    allowed[key] = s
#  end
#
#  # Analyze all <> elements
#  stack = Array.new
#  result = html.gsub( /(<.*?>)/m ) do | element |
#    if element =~ /\A<\/(\w+)/ then
#      # </tag>
#      tag = $1.downcase
#      if allowed.include?(tag) && stack.include?(tag) then
#        # If allowed and on the stack
#        # Then pop down the stack
#        top = stack.pop
#        out = "</#{top}>"
#        until top == tag do
#          top = stack.pop
#          out << "</#{top}>"
#        end
#        out
#      end
#    elsif element =~ /\A<(\w+)\s*\/>/
#      # <tag />
#      tag = $1.downcase
#      if allowed.include?(tag) then
#        "<#{tag} />"
#      end
#    elsif element =~ /\A<(\w+)/ then
#      # <tag ...>
#      tag = $1.downcase
#      if allowed.include?(tag) then
#        if ! soloTags.include?(tag) then
#          stack.push(tag)
#        end
#        if allowed[tag].length == 0 then
#          # no allowed attributes
#          "<#{tag}>"
#        else
#          # allowed attributes?
#          out = "<#{tag}"
#          while ( $' =~ /(\w+)=("[^"]+")/ )
#            attr = $1.downcase
#            valu = $2
#            if allowed[tag].include?(attr) then
#              out << " #{attr}=#{valu}"
#            end
#          end
#          out << ">"
#        end
#      end
#    end
#  end
#
#  # eat up unmatched leading >
#  while result.sub!(/\A([^<]*)>/m) { $1 } do end
#
#  # eat up unmatched trailing <
#  while result.sub!(/<([^>]*)\Z/m) { $1 } do end
#
#  # clean up the stack
#  if stack.length > 0 then
#    result << "</#{stack.reverse.join('></')}>"
#  end
#
#  result
#end