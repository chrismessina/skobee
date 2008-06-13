module CompressionSystem
  
  alias orig_accepts_gzip? accepts_gzip?
  
  def accepts_gzip?
    #MES- For some reason, we're having problems with IE and compressed
    # content (see ticket #742.)  I did a bunch of Google searches, which
    # found lots of problems with IE and gzip compression, but none that
    # look just like our problem.  I looked at our problem in Ethereal, and
    # it looks like the web server is returning EXACTLY the same thing
    # in cases that work and cases that don't.  So, to get around this,
    # I'm just disabling compression for IE (kinda sucks, I know.)
    return false if ie?
    return orig_accepts_gzip?
  end
end