class Array
  def to_hash
    #MES- Self is assumed to be an array of arrays.  Each
    # Each sub array must have two elements.  The first will
    # be treated as the key, and the second will be treated
    # as the value.
    ret = Hash.new
    self.each do | item |
      ret[item[0]] = item[1]
    end
    ret
  end
end