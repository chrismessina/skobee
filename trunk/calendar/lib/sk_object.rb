class Object
  #MES- copy_from copies data from the source to "self".
  # For example, this code:
  #   a.x = b.x
  #   a.y = b.y
  #   a.z = b.z
  # could be rewritten as
  #   a.copy_from b, :x, :y, :z
  def copy_from(source, *items_to_copy)
    items_to_copy.each do | item |
      #MES- The "setter" method is the same as the source, but with a equals sign at the end
      setter = (item.to_s + '=').to_sym
      #MES- Convert the item to a symbol, if it's not already one
      item = item.to_sym
      #MES- Call the setter, passing in the result from the source
      self.send(setter, source.send(item))
    end
  end
end