#MES- From C:\ruby\lib\ruby\gems\1.8\gems\actionmailer-1.2.1\lib\action_mailer\vendor\tmail\mail.rb
class TMail::Mail
  #MES- Given an email in multipart mime format, return the
  # body of the plaintext section
  def plaintext_body
    if multipart?
      parts.each do |part|
        if 'text/plain' == part.content_type
          if 'quoted-printable' == part.content_transfer_encoding
            #MES- We're seeing some weird stuff with quoted printable encoding.
            # The email contained in 'marks_bad_email.txt' illustrates it.  Under
            # quoted-printable encoding, the lines are limited to 76 characters, but
            # a longer line can be broken up by adding "=\r\n" (as I read the spec.)
            # Here's the section of the spec, from http://www.ietf.org/rfc/rfc2045.txt:
            #
            #    (Line Breaks) A line break in a text body, represented
            #    as a CRLF sequence in the text canonical form, must be
            #    represented by a (RFC 822) line break, which is also a
            #    CRLF sequence, in the Quoted-Printable encoding.
            #
            #    (Soft Line Breaks) The Quoted-Printable encoding
            #    REQUIRES that encoded lines be no more than 76
            #    characters long.  If longer lines are to be encoded
            #    with the Quoted-Printable encoding, "soft" line breaks
            #    must be used.  An equal sign as the last character on a
            #    encoded line indicates such a non-significant ("soft")
            #    line break in the encoded text.
            # However, the email in question (which is from Gmail), contains
            # "=\r", which is a disallowed end-of-line.
            # Worse, it seems like the Ruby quoted-printable decoder doesn't
            # decode it correctly, EVEN IF it's encoded right!
            # Check out this IRB session:
            #    irb(main):001:0> "test=\r\ning".unpack('M')
            #    => ["test"]
            #    irb(main):002:0> "test=\ning".unpack('M')
            #    => ["testing"]
            # This is consistent across Windows and Linux.
            # Finally, TMail doesn't return the whole body- it chops it off
            # after the "=\r" when we call part.body.  Calling part.each does NOT
            # seem to have this flaw.  Go figure.
            
            #MES- Get the whole plaintext body
            str = ''
            part.each do | line |
              str += line
            end
            #MES- Replace every line ending variation with \n, and do a 
            # quoted-printable decoding
            return str.gsub(/(\r\n|\n\r|\r)/, "\n").unpack('M')[0]
          else
            return part.body
          end
        end
      end
      #MES- Failed!
      return nil
    else
      return body
    end
  end
  
  #MES- Given an email in multipart mime format, return the
  # body of the html section
  def html_body
    if multipart?
      parts.each do |part|
        if 'text/html' == part.content_type
          return part.body
        end
      end
    end
    
    #MES- Failed!
    return nil
  end
  
  #MES- Was this email sent from an Exchange server?
  def from_exchange?
    #MES- For various reasons, Exchange is a pain in the butt.  We need
    # to handle Exchange emails special in various places in the code,
    # and this function helps those places
    xmime = self['X-MimeOLE']
    if !xmime.nil? && xmime.to_s.match('Microsoft')
      return true
    end
    
    return false
  end
end