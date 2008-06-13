# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include UserSystem
  include Sanitize

  #MES- Constants related to handling AJAX errors
  #MES- AJAX_HTTP_ERROR_STATUS is the HTTP response status code corresponding to
  # a Skobee internal error- an error that Skobee is able to report.  This is
  # a custom error code, because we want AJAX clients to be able to distinguish
  # between a Skobee error (where Skobee has recognized the error and returned HTML that
  # describes or otherwise handles the error) and an unhandled error (which might result
  # in, say, a 500 response status.
  AJAX_HTTP_ERROR_STATUS = '590 Skobee Internal Server Error'
  #MES- AJAX_HTTP_ERROR_STATUS_HANDLER_FRAGMENT is a fragment of JavaScript that
  # can be used in calls to "new Ajax.Request" to handle errors that include a response
  # of AJAX_HTTP_ERROR_STATUS- basically, these two constants go together and should be
  # kept in sync.
  AJAX_HTTP_ERROR_STATUS_HANDLER_FRAGMENT = 'on590'


  #KS- used for general storage of truth values in the db
  DB_TRUE_VALUE_STRING = '1'
  DB_FALSE_VALUE_STRING = '0'

  HTTP_USER_AGENT = "HTTP_USER_AGENT"

  ICAL_QUERYSTRING_KEY = "display_ical_feed"

  #MES- If the request was a GET (as opposed to a POST), show the view for
  # the current action, displaying the User object that is currently in the
  # session.
  #NOTE: This code came with SaltedLoginGenerator.
  def show_session_user_on_get
    @user = current_user
    if :get == @request.method
      render
      return true
    end
    return false
  end

  #MES- Returns the HTML needed to display a thumbnail for the user, including the
  # link to the users' profile
  #MGS- adding the ability to add a caption to the thumbnail link
  def build_user_thumbnail_link(user, caption=nil)
    return link_to("#{build_user_thumbnail_url(user)}<br />#{h(caption)}", { :controller => 'user', :action => user.login })
  end

  def build_user_profile_link(user, text = '')
    #MES- If there's no user, just show the text NOT as a link
    if user.nil?
      return text
    end
    #MES- If the text is empty, use the display name
    text = user.display_name if text.empty?
    return link_to(h(text), { :controller => 'user', :action => user.login })
  end

  #MGS- helper function to return img tag string for thumbnail images
  def build_user_thumbnail_url(user, options = {})
    options[:alt] = user.display_name if options[:alt].nil?

    if !user.thumbnail.nil?
      return image_tag(
        url_for(
          :controller => 'pictures',
          :action => 'show',
          :id => "#{user.thumbnail.id}#{user.thumbnail.extension}"),
          options)
    else
      return default_user_thumbnail_url
    end
  end

  def default_user_thumbnail_url
    return "<img alt=\"no user thumbnail\" src='/images/noimage.gif'/>"
  end

  #MGS- helper function to return img tag string for thumbnail images
  def build_user_image_url(user)
    if !user.image.nil?
      return image_tag(url_for(:controller => 'pictures', :action => 'show', :id => "#{user.image.id}#{user.image.extension}"), :alt => user.display_name)
    else
      return "<img alt=\"no user image\" src='/images/noimage.gif'/>"
    end
  end

  #MGS- helper function to return img tag string for thumbnail images
  def build_thumbnail_url(thumbnail, options = nil)
    options = Hash.new if options.nil?
    options[:alt] = "#{thumbnail.name}"

    if !thumbnail.nil?
      return image_tag(
        url_for(
          :controller => 'pictures',
          :action => 'show',
          :id => "#{thumbnail.id}#{thumbnail.extension}"),
        options)
    else
      return "<img alt=\"no user thumbnail\" src='/images/noimage.gif'/>"
    end
  end

  #KS: ensure that a string is not empty or nil. used to figure out which input
  #fields are active in stuff like place search
  def not_empty_or_nil(string)
    return !string.nil? && string != ''
  end

  #MGS- add html elements to the yft array to flash
  def add_yft_to_flash(element_to_flash)
    if flash[:yft].nil?
      flash[:yft] = Array.new
    end
    flash[:yft]  << element_to_flash
  end

  #MES- This function copies items in a hash into instance members.
  # For instance, calling:
  #   hash_to_members(params, :item_1, :item_2)
  # is equivalent to calling:
  #   @item_1 = params[:item_1]
  #   @item_2 = params[:item_2]
  def hash_to_members(hash, *items_to_copy)
    items_to_copy.each do | item |
      instance_var = ('@' + item.to_s).to_sym
      self.instance_variable_set(instance_var, hash[item])
    end
  end

  #MES- Returns the passed in anchor if the user is logged in,
  # otherwise returns an anchor tag pointing to the login page
  # (with the supplied label)
  def anchor_or_login(intended_destination, label, options = '')
    if logged_in?
      return intended_destination
    else
      return "<a href=#{url_for(:controller => 'users', :action => 'login')} #{options}>#{label}</a>"
    end
  end

  #MGS- uses the request hostname to return the appropriate google maps key
  def google_maps_key
    hostname = @request.host_with_port
    if GOOGLE_MAP_KEYS.has_key?(hostname)
      return GOOGLE_MAP_KEYS[hostname]
    else
      logger.error "***** Google Maps Key Not Found for #{hostname} *****"
      return GOOGLE_MAP_KEYS['www.skobee.com']
    end
  end

  def google_maps_script
    #MGS- writes out the script tag to include google maps on a page
    # put in one place so we can easily update the version, etc.
    # API's discussed here: http://googlemapsapi.blogspot.com/
    return "<script src=\"http://maps.google.com/maps?file=api&amp;v=2.42&amp;key=#{google_maps_key}\" type=\"text/javascript\"></script>"
  end

  def google_maps_link(place)
    #MGS- helper to build google maps links
    if !place.nil? && !place.location.nil?
      return "http://maps.google.com/maps?q=#{CGI::escape(place.location)}&iwloc=A&hl=en"
    else
      return ""
    end
  end

  #KS- create the autocomplete array string for injection into the page for
  #autocomplete
  #MGS- adding ability to remove users from being displayed in the autocomplete list
  def generate_user_autocomplete_arrays(user_id, search_array_name, excluded_users = nil)
    user = User.find(user_id)

    contacts = user.contacts
    #MGS- remove the excluded users from the array if an excluded user array was passed in
    contacts = contacts - excluded_users if !excluded_users.nil?

    #KS- build the array in ruby first
    ruby_search_array = []
    contacts.each {|contact|
      ruby_search_array << "#{contact.real_name} (#{contact.login})"
    }

    #KS- now build the javascript array inside a ruby string; i left out spaces
    #so it won't be very readable in the HTML. do we care?
    javascript_arrays_string = "var #{search_array_name} = new Array();"
    ruby_search_array.each {|searchable_string| javascript_arrays_string << "#{search_array_name}[#{search_array_name}.length] = \"#{escape_javascript(searchable_string)}\";"}

    return javascript_arrays_string
  end

  #KS- create the place autocomplete array string for use by the PlaceSearchByNameAutocompleter
  def generate_place_autocomplete_array(user_id, search_array_name)
    user = User.find(user_id)

    my_places = Place.find_user_places(user)

    #KS- build the javascript array inside a ruby string. the array is structured as follows:
    #index 0: an array of all the place ids corresponding to the places in the array at index 1
    #index 1: an array of all the place names
    #index 2: an array of all the place address + cities in parens if they both exist
    #KS- note that this array structure is identical to the ruby array found in PlansController#auto_complete_responder_for_place_list
    javascript_arrays_string = ""
    javascript_arrays_string << "var place_id_array = new Array();"
    javascript_arrays_string << "var place_name_array = new Array();"
    javascript_arrays_string << "var place_address_array = new Array();"
    javascript_arrays_string << "var place_normalized_name_array = new Array();"
    my_places.each { |place|
      javascript_arrays_string << "place_id_array[place_id_array.length] = \"#{place.id}\";"
      javascript_arrays_string << "place_name_array[place_name_array.length] = \"#{escape_javascript(h(place.name))}\";"
      javascript_arrays_string << "place_address_array[place_address_array.length] = \"" +
        (place.address.nil? || place.city.nil? ? "" : " (#{escape_javascript(h(place.address))}, #{escape_javascript(h(place.city))})") + "\";"
      javascript_arrays_string << "place_normalized_name_array[place_normalized_name_array.length] = \"#{escape_javascript(h(place.normalized_name))}\";"
    }
    javascript_arrays_string << "var #{search_array_name} = [place_id_array, place_name_array, place_address_array, place_normalized_name_array];"

    return javascript_arrays_string
  end

  def format_rich_text(s)
    #MGS- takes a string and encodes it for html, generates links for urls
    # and translates line breaks into html line breaks.
    #MGS- perform html encoding on everything but & (ampersands) as we want to allow those to appear in urls
    #MGS- adding target = _blank to force links to open in new window
    #MGS- call the sanitize_text function to remove all html tags, but those allowed in the function (like <i>, <b>, etc)
    return simple_format(auto_link(sanitize_text(s), :all, :target => '_blank'))
  end

  #MES- format_plain_text is similar to format_rich_text, but returns the text as "plaintext", suitable
  # for inclusion in plaintext emails, etc.
  def format_plain_text(s)
    #MES- Currently, the text is not allowed to contain any tags or anything like that, so just return it
    return s
  end

  def comment_help_link
    #MGS- common place to generate the window.open for the comment html help
    txt = <<-END_OF_STRING
    <a href="#" onclick="window.open('/help/comments_html_guide','html','status=yes,scrollbars=yes,resizable=yes,width=700,height=350');return false">Want to add a little sizzle to your comments?</a>
    END_OF_STRING
    return txt
  end

  #MGS- helper functions to get the browser type
  def firefox?
    session[:firefox]
  end

  def ie?
    session[:ie]
  end

  def safari?
    session[:safari]
  end

  def generate_ical_key(user, planner_id)
    #MGS- generate a hash of a string, the user's salt and the planner_id/user_id.
    # This way we ensure the user_id/planner_id combo is correct in the querystring.
    return User.hashed(ICAL_QUERYSTRING_KEY + user.salt + planner_id.to_s + user.id.to_s)
  end
end
