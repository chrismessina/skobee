class Comment < ActiveRecord::Base
  belongs_to :owner, :class_name => 'User', :foreign_key => 'owner_id'
  before_save :truncate_body!

  #MGS- deletes the comment and reference on parent object (ie plan/place)
  #MGS- adding a way to skip this security check, so user's can delete comments
  # off their profiles which they did not create; the security check is really
  # done in the controller for these.
  def delete_from_collection(usr, coll, bypass_security = false)
    if bypass_security || check_security(usr)
      coll.delete self
      self.destroy
    end
  end

  #MGS- check to make sure current user is the owner of comment
  def check_security(usr)
    raise "Wrong user to edit/delete comment (was #{usr.id} but should be #{owner.id})!" if usr != owner
    return true
  end

  def truncate_body!
    #MGS- we want to silently handle the case where the user enters more text than we can handle for the body (like flickr)
    # only saving the first 4096 characters.
    self.body.slice!(4096..-1) if !self.body.nil?
  end

  #MGS- Define the default sort
  def <=>(other)
    #MGS- Sort by created_at, if they're different
    st = self.created_at <=> other.created_at
    return (-1 * st) if 0 != st #MGS- -1 for descending

    #MGS- They're the same, sort by id
    return -1 * (self.id <=> other.id) #MGS- -1 for descending
  end
end
