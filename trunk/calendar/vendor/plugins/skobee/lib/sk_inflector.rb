#MES- From C:\ruby\lib\ruby\gems\1.8\gems\activesupport-1.3.1\lib\active_support\inflector.rb
module Inflector
  extend self
  #MGS- all of the other pluralization helpers are in Inflector
  #currently there's no possessive string generator...probably because they couldn't come up with a name for it
  #this name sucks, but its kind of fun and in the spirit of constantize and the other made-up inflectors
  def possessiveize(word)
    #MGS- add 's unless word ends in s, then just add '
    's' == word[-1].chr ? word + "'" : word + "'s"
  end
end