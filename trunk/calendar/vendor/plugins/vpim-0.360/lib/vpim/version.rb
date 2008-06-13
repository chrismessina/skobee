=begin
  Copyright (C) 2006 Sam Roberts

  This library is free software; you can redistribute it and/or modify it
  under the same terms as the ruby language itself, see the file COPYING for
  details.
=end

module Vpim
#MGS- Skobee needs our own PRODID...
  PRODID = '-//Skobee//ICal//EN'

  VERSION = '0.360'

  # Return the API version as a string.
  def Vpim.version
    VERSION
  end
end
