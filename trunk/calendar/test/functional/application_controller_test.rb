require File.dirname(__FILE__) + '/../test_helper'
require 'application'
require 'application_helper'

# Re-raise errors caught by the controller.
class ApplicationController; def rescue_action(e) raise e end; end

#########################################################################################
#MES- Tests that rely on users and planners
#########################################################################################

class ApplicationControllerTest_UserStuff < Test::Unit::TestCase

  fixtures :planners, :users, :emails, :planners_plans, :plans

  def setup
    @controller = ApplicationController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_cancel
    #MGS- the cancel action should be available from all controllers
    login users(:existingbob)
    #MGS- set the redirect back
    http_to_controller(:get, UsersController.new, :contacts, {})
    assert_success
    http_to_controller(:get, PlansController.new, :new, {})
    assert_success
    http_to_controller(:get, PlansController.new, :cancel_and_redirect, {:id => plans(:another_plan).id})
    assert_redirected_to "/users/contacts"

    #MGS- set the redirect back
    http_to_controller(:get, PlannersController.new, :schedule_details, {})
    assert_success
    http_to_controller(:get, PlacesController.new, :new, {})
    assert_success
    http_to_controller(:get, PlacesController.new, :cancel_and_redirect, {})
    assert_redirected_to "/planners/schedule_details"
  end

  def test_browser_checking
    login

    http_to_controller(:get, PlannersController.new, :schedule_details, {})
    #the default user-agent string in the functional tests is null
    assert_session_equal false, :firefox
    assert_session_equal false, :ie
    assert_session_equal false, :safari

    #MGS- TODO figure out how to set headers in functional tests
    #login users(:existingbob)
    #http_to_controller(:get, PlacesController.new, :new, {'HTTP_USER_AGENT' => 'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en) AppleWebKit/412 (KHTML, like Gecko) Safari/412'})
    #assert_session_equal false, :firefox
    #assert_session_equal false, :ie
    #assert_session_equal true, :safari
  end

end

#########################################################################################
#MES- Simple tests that don't require any fixtures
#########################################################################################

class ApplicationControllerTest_NoFixtures < Test::Unit::TestCase
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::TagHelper
  include ApplicationHelper

  def test_auto_link
    #MGS- since auto_link is customized, we need to test it
    # make sure it handles @ and ~ in the url and /?
    txt = <<-END_OF_STRING
      This flickr link is pretty cool
      check it out:
      http://www.flickr.com/photos/89911364@N00/sets/72057594065165261/
      See it's cool.
    END_OF_STRING
    assert auto_link(txt).match("<a href=\"http://www.flickr.com/photos/89911364@N00/sets/72057594065165261/\">http://www.flickr.com/photos/89911364@N00/sets/72057594065165261/</a>")

    txt = "http://www.skobee.com?dfddsfd=dfsdsf&dfsfgsd=dfdsf fzdzgfdgfd"
    assert_equal "<a href=\"http://www.skobee.com?dfddsfd=dfsdsf&dfsfgsd=dfdsf\">http://www.skobee.com?dfddsfd=dfsdsf&dfsfgsd=dfdsf</a> fzdzgfdgfd", auto_link(txt)

    txt = "http://www.hawaii.edu/~name/index.html"
    assert_equal "<a href=\"http://www.hawaii.edu/~name/index.html\">http://www.hawaii.edu/~name/index.html</a>", auto_link(txt)
  end

  def test_format_rich_text
    #MGS- test the basic tags we support
    txt = "this should be <u>underlined</u>"
    assert_equal txt, format_rich_text(txt)
    txt = "this should be <i>italicized</i>"
    assert_equal txt, format_rich_text(txt)
    txt = "this should be <b>bold</b>"
    assert_equal txt, format_rich_text(txt)
    txt = 'this should be an <a href="http://www.espn.com">url</a>'
    assert_equal txt, format_rich_text(txt)
    txt = 'this should be an  <img src="http://www.espn.com"> image>'
    assert_equal 'this should be an  <img src="http://www.espn.com"/> image>', format_rich_text(txt)
    #MGS- try the anchor tag with an autolink tag
    txt = 'this should be an <a href="http://www.espn.com">url</a> and http://www.espn.com'
    assert_equal 'this should be an <a href="http://www.espn.com">url</a> and <a href="http://www.espn.com" target="_blank">http://www.espn.com</a>', format_rich_text(txt)

    #MGS- now test some tags that we don't support
    txt = "dsgsdgdsg <br>"
    assert_equal "dsgsdgdsg &lt;br&gt;", format_rich_text(txt)
    txt = "dsgsdgdsg <p>"
    assert_equal "dsgsdgdsg &lt;p&gt;", format_rich_text(txt)
    txt = "dsgsdgdsg <table><tr><td>inside</td></tr></table> asdf"
    assert_equal "dsgsdgdsg &lt;table&gt;&lt;tr&gt;&lt;td&gt;inside&lt;/td&gt;&lt;/tr&gt;&lt;/table&gt; asdf", format_rich_text(txt)
    txt = "sdgdsg <div> gdfsgfg"
    assert_equal "sdgdsg &lt;div&gt; gdfsgfg", format_rich_text(txt)
    txt = "sdgdsg </div> gdfsgfg"
    assert_equal "sdgdsg &lt;/div&gt; gdfsgfg", format_rich_text(txt)
    txt = "sdgdsg </div/> gdfsgfg"
    assert_equal "sdgdsg &lt;/div/&gt; gdfsgfg", format_rich_text(txt)
    txt = "sdgdsg </di/v/> gdfsgfg"
    assert_equal "sdgdsg &lt;/di/v/&gt; gdfsgfg", format_rich_text(txt)

    #MGS- now try just < and > in the txt
    txt = "one > two < three"
    assert_equal "one &gt; two &lt; three", format_rich_text(txt)

    #MGS- try some combos of image attributes
    txt = 'this should be an  <img src="http://www.espn.com" title="bsd"> image>'
    assert_equal 'this should be an  <img src="http://www.espn.com" title="bsd"/> image>', format_rich_text(txt)
    txt = 'this should be an  <img src="http://www.espn.com" title="bsd" alt="espn"> image>'
    assert_equal 'this should be an  <img src="http://www.espn.com" title="bsd" alt="espn"/> image>', format_rich_text(txt)
    txt = 'this should be an  <img src="http://www.espn.com" title="bsd" alt="espn" width="32" height="33"> image>'
    assert_equal 'this should be an  <img src="http://www.espn.com" title="bsd" alt="espn" width="32" height="33"/> image>', format_rich_text(txt)
  end


end

