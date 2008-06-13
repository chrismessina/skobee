module UserHelper

  def self.convert_expanded_to_screen_name(expanded)
    expanded.sub!(/[^\(]*\(/, '')
    expanded.sub!(/\)[^\)]*/, '')
  end

  #MES- The following helpers are used by the views and controller to
  # handle user attributes more like properties of the user.  We want
  # to emulate functions like text_field or check_box

  #MES- Return a text field HTML element that displays the
  # indicated attribute for the user.
  def text_field_user_att(user, att_id, options = {})
    return text_field_tag("user_atts[#{att_id}]", user.get_att_value(att_id), options.update({:id => "user_atts_#{att_id}"}))
  end

  #MES- Return a select HTML element that displays the
  # indicated attribute for the user.
  # Options to be displayed are passed in via 'choices',
  # which is an array of [value, description] items.
  def select_field_user_att(user, att_id, choices, options = {})
    return select_field_tag("user_atts[#{att_id}]", user.get_att_value(att_id), choices, options.update({:id => "user_atts_#{att_id}"}))
  end
  
  #MES- Return a select HTML element that displays the
  # indicated attribute for the user.
  # Options to be displayed are passed in via 'choices',
  # which is an array of [value, description] items.
  def select_field_user_security_att(user, group_id, choices, options = {})
    return select_field_tag("security_atts[#{group_id}]", user.get_att_value(UserAttribute::ATT_SECURITY, group_id), choices, options.update({:id => "security_atts_#{group_id}"}))
  end

  #MES- Return a radio button HTML element that displays the
  # indicated attribute for the user.
  # value is the value of the radio item
  # id_modifier is a string that is appended to the ID
  #   field to differentiate this radio button from other
  #   radio buttons that have the same name on the form.
  def radio_button_user_att(user, att_id, value, id_modifier, options = {})
    return radio_button_tag("user_atts[#{att_id}]", value, (user.get_att_value(att_id) == value), options.update({:id => radio_button_user_att_id(att_id, id_modifier)}))
  end
  
  #MES- Returns a label for use with radio_button_user_att
  def label_for_user_att_radio(text, att_id, id_modifier)
    return "<label for='#{radio_button_user_att_id(att_id, id_modifier)}'>#{text}</label>"
  end
  
  #MES- Returns the ID of the control returned by radio_button_user_att
  def radio_button_user_att_id(att_id, id_modifier)
    return "user_atts_#{att_id}_#{id_modifier}"
  end

  #MES- Return a check box HTML element that displays the
  # indicated attribute for the user.
  # value is the value of the check item.
  def check_box_user_att(user, att_id, value, options = {})
    return check_box_tag("user_atts[#{att_id}]", value, (user.get_att_value(att_id).to_s == value.to_s), options.update({:id => check_box_user_att_id(att_id)}))
  end
  
  #MES- Returns a label for use with check_box_user_att
  def label_for_user_att_check(text, att_id)
    return "<label for='#{check_box_user_att_id(att_id)}'>#{text}</label>"
  end
  
  #MES- Returns the ID of the control returned by check_box_user_att
  def check_box_user_att_id(att_id)
    "user_atts_#{att_id}"
  end

  #MES- Given a form that was populated via text_field_user_att,
  # select_field_user_att, etc., copy the posted data into the
  # user object (i.e. set the user attributes.)
  def set_atts_from_post(post_data, user)
    #MES- Did we get any post data?
    if post_data.has_key? 'user_atts'
      #MES- Run through the post data hash
      post_data['user_atts'].each_pair do | key, value |
        #MES- Set this att- the key is a number, but posts
        # convert to strings, so we do a to_i.
        user.set_att(key.to_i, value)
      end
    end
  end
  
  #KS- basically the same as the set_atts_from_post method but 
  #instead of setting atts, assumes the atts were security atts
  def set_security_atts_from_post(post_data, user)
    #MES- Did we get any post data?
    if post_data.has_key? 'security_atts'
      #MES- Run through the post data hash
      post_data['security_atts'].each_pair do | key, value |
        #MES- Set this att- the key is a number, but posts
        # convert to strings, so we do a to_i.
        user.set_att(UserAttribute::ATT_SECURITY, value, key.to_i)
      end
    end
  end

end
