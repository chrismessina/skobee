ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'

#MES- Including test/time, which is needed by UsersControllerTest#test_delete
require File.dirname(__FILE__) + '/mocks/test/time'
require File.dirname(__FILE__) + '/mocks/test/user_notify'
require File.dirname(__FILE__) + '/mocks/test/flickr'

class Test::Unit::TestCase
  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  # Every Active Record database supports transactions except MyISAM tables
  # in MySQL.  Turn off transactional fixtures in this case; however, if you
  # don't care one way or the other, switching from MyISAM to InnoDB tables
  # is recommended.
  self.use_transactional_fixtures = true

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  self.use_instantiated_fixtures  = false

  # Add more helper methods to be used by all tests here...

  #MES- My helpers here
  def assert_redirect_to_login
    assert_redirected_to({:controller => 'users', :action => 'login'}, 'Action was expected to redirect to the login page, but did not')
  end

  def login(username = 'bob', password = 'atest')
    #MGS- always logout first
    post_to_controller UsersController.new, :logout

    if username.is_a? User
      username = username.login
    end
    #MES- Post login information to the login method in the user controller
    post_to_controller UsersController.new, :login, "user" => { "login" => username, "password" => password }
    assert_session_has 'user_id', "Login failed for user #{username} with password #{password}"
  end

  def logout
    #MES- Use the get method to log out
    get_to_controller UsersController.new, :logout
    assert_session_has_no 'user_id', 'Logout failed'
  end


  #MES- A helper that 'posts' the indicated information
  def post_to_controller(controller, action, params = {})
    http_to_controller(:post, controller, action, params)
  end

  #MES- A helper that 'gets' the indicated information
  def get_to_controller(controller, action, params = {})
    http_to_controller(:get, controller, action, params)
  end

  #MES- Send an HTTP message to the indicated controller via
  #  the indicated method
  def http_to_controller(method, controller, action, params)
    #MES- Store the current controller
    backup_controller = @controller
    begin
      #MES- Swap in the indicated controller
      @controller = controller

      #MES- Send the HTTP message
      self.send(method, action, params)
    ensure
      #MES- Swap back in the controller
      @controller = backup_controller
      #MES- Remake the request, but save the session
      new_req = ActionController::TestRequest.new
      new_req.session = @request.session
      @request = new_req
    end
  end

  #KS: A helper that reads in an entire file and puts the contents into a string
  def file_to_string(file_location)
    #MES- NOTE: Reading in BINARY mode, so that tests act the same on Windows and Linux
    f = File.open(file_location, 'rb')
    res = f.read
    f.close
    return res
  end
  
  
  #MES- Some helpers for file upload, from http://manuals.rubyonrails.com/read/chapter/28
  
  # get us an object that represents an uploaded file
  def uploaded_file(path, content_type="application/octet-stream", filename=nil)
    filename ||= File.basename(path)
    #MES- Slight modification here.  The code USED to use a Tempfile, but 
    # Tempfile::new doesn't take in a mode argument, and the mode must be
    # binary for this to work on Windows.  Why isn't binary the default mode?
    # Grrr...
    #t = Tempfile.new(filename)
    #FileUtils.copy_file(path, t.path)
    t = File.new(path, 'rb')
    (class << t; self; end;).class_eval do
      alias local_path path
      define_method(:original_filename) { filename }
      define_method(:content_type) { content_type }
    end
    return t
  end
  
  # a JPEG helper
  def uploaded_jpeg(path, filename=nil)
    uploaded_file(path, 'image/jpeg', filename)
  end
  # a PJPEG helper
  def uploaded_pjpeg(path, filename=nil)
    uploaded_file(path, 'image/pjpeg', filename)
  end
  
  # a PNG helper
  def uploaded_png(path, filename=nil)
    uploaded_file(path, 'image/png', filename)
  end
  
  # a BMP helper
  def uploaded_bmp(path, filename=nil)
    uploaded_file(path, 'image/bmp', filename)
  end
  
  # a GIF helper
  def uploaded_gif(path, filename=nil)
    uploaded_file(path, 'image/gif', filename)
  end
  
  # a TIFF helper
  def uploaded_tiff(path, filename=nil)
    uploaded_file(path, 'image/tiff', filename)
  end
  
end

class String
  #MES- Treat the string as a HTTP querystring, and split it
  # into key/value pairs.  Then put the pairs into a map.
  # There has GOT to be a Rails method that does this, but 
  # I couldn't find it.
  def querystring_to_map
    map = {}
    self.split('&').each do | item |
      subitems = item.split('=')
      key = subitems[0]
      value = subitems[1]
      #MES- If the key looks like 'user[id]', it's a map of maps
      qs_add_key(map, CGI::unescape(key), CGI::unescape(value))
    end
    return map
  end
  
  #MES- Helper for querystring_to_map
  def qs_add_key(map, key, value)
    #MES- Take in a key like 'a[b[c]]' and a value
    # like 'd', and make a map entry like
    # {'a' => { 'b' => { 'c' => 'd' } } }
    key_arr = qs_key_to_arr(key)
    while (1 < key_arr.length)
      subkey = key_arr.shift
      map[subkey] ||= {}
      map = map[subkey]
    end
    map[key_arr.shift.to_s] = value
  end
  
  #MES- Helper for qs_add_key
  def qs_key_to_arr(key, prev = [])
    #MES Take in a key like 'a[b[c]]' and return
    # ['a', 'b', 'c'].  'a' returns ['a'].
    m = key.match(/^([^\[]*)\[(.*)\]$/)
    if m.nil?
      prev << key
    else
      prev << m[1]
      return qs_key_to_arr(m[2], prev)
    end
    return prev
  end
  
end

#KS: not sure if this is the correct place for a mock object, but i needed to
# use it in both a unit test and a functional test.
class MockEmail

  def initialize(message_id, in_reply_to, references)
    @message_id = message_id
    @in_reply_to = in_reply_to
    @references = references
  end

  def message_id
    @message_id
  end

  def in_reply_to
    @in_reply_to
  end

  def references
    @references
  end

end



module Kernel
  private

  @@mock_opens = nil

  REPORT_AND_CREATE_MISSING_MOCKS = false

  #MES- This is meant to mock out open- when looking for one
  # item, this may actually open a different item.
  # I intend to use it for turning an Open-URI call in a test
  # into a simple file open.
  def skobee_mock_open(name, *rest, &block)
    #MES- Are we set up and is the item to open a string?
    if @@mock_opens && name.is_a?(String)
      redirected = @@mock_opens[name]
      if !redirected.nil?
        return skobee_open_before_mocked(redirected, *rest, &block)
      else
        #MES- This block is used to detect and set up missing mocks.  Enable it
        # when you add tests that need new mocks (by setting the constant to true.)
        if REPORT_AND_CREATE_MISSING_MOCKS
          puts "Mock for location not found:"
          puts "    #{name}"
          puts "    caller is:"
          caller.each { | item | puts "      #{item}" if item.match('_test.rb')}
          outname = './test/mocks/resources/' + Zlib::crc32(name).to_s + '.out'
          skobee_open_before_mocked(name, *rest) do | inp |
            skobee_open_before_mocked(outname, "w") do | outp |
              inp.each { | line | outp.write line }
            end
          end
          puts "    Wrote output to #{outname}"
        end
      end
    end

    skobee_open_before_mocked(name, *rest, &block)
  end
  
  #MES- Hand this code a map of mock opens and a code block, and the block
  # will be executed with the indicated mocks.  This is safer than calling
  # setup_mock_opens and clear_mock_opens directly because it guarantees that
  # clear_mock_opens will get called.
  def with_mock_opens(mock_opens)
    setup_mock_opens(mock_opens)
    yield
    clear_mock_opens
  end

  def setup_mock_opens(mock_opens)
    @@mock_opens = mock_opens
    #MES- Rename the ORIGINAL open to a new name
    alias :skobee_open_before_mocked :open
    #MES- And rename OUR mock open to the ORIGINAL name
    alias :open :skobee_mock_open
  end

  def clear_mock_opens()
    @@mock_opens = nil
    #MES- Undo the naming shenanigans
    alias :skobee_mock_open :open
    alias :open :skobee_open_before_mocked
  end

  module_function :skobee_mock_open
  module_function :setup_mock_opens
  module_function :clear_mock_opens
end