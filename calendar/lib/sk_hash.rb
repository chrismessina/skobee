class Hash

  #Find items in this hash where the key starts with the supplied
  # prefix.  For those items that match, strip the prefix, and add
  # to a new hash with the stripped key.  Return the new hash.
  def find_and_strip_prefixes(prefix)
    ret = {}
    pref_len = prefix.length
    self.each do | key, value |
      if key[0, pref_len] == prefix
        key_without_prefix = key[prefix.length,key.length]
        ret[key_without_prefix] = value
      end
    end

    return ret
  end
end