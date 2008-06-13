END {$ie.close if $ie} # close ie at completion of the tests

#MGS- including watir
require 'rubygems'
require 'watir'
require 'test/unit'

def start_ie_with_logger
  $ie = Watir::IE.new()
  $ie.logger = Watir::WatirLogger.new( 'debug.txt', 4, 10000 )
  $ie.set_fast_speed
end

def set_local_dir
  $myDir = File.expand_path(File.dirname(__FILE__))
  $myDir.sub!( %r{/cygdrive/(\w)/}, '\1:/' ) # convert from cygwin to dos
  # if you run the unit tests form a local file system use this line
  #$htmlRoot =  "file://#{$myDir}/html/"
  # if you run the unit tests from a web server use this line
  $htmlRoot =  "http://localhost:3000/"
end


#MGS- ghetto way that waitr handles javascriptpop-up windows
# needs to be called before the action that can trigger the popup
public
def startClicker( button , waitTime = 3)
  w = WinClicker.new
  longName = $ie.dir.gsub("/" , "\\" )
  shortName = w.getShortFileName(longName)
  #MGS - changing to run with ruby instead of rubyw because rubyw was hanging
  c = "start ruby #{shortName }\\watir\\clickJSDialog.rb #{button } #{ waitTime} "
  puts "Starting #{c}"
  w.winsystem(c)
  w=nil
  #assert_same(expected, actual, [message] ) #Expects expected.equal?(actual)
end

#KS- use to test autocomplete boxes.
#match_string: string to match against
#type_string: string the watir test will type into the form field
#div_id: id of the div autocomplete info is expected to show up in
#field_id: the field the autocompleted stuff gets put into when the autocomplete option is chosen
#should_match: should the autcomplete info given show up in the autocomplete options?
def assert_autocomplete(match_string, type_string, div_id, field_id, should_match)
  contact_autocomplete_div = $ie.div(:id, div_id)

  # the planner div shouldn't be visible, unless you click the link to enable it
  #MGS- TODO this has been buggy lately, so commenting it out for the time being
  # we should reevaluate at some point how best to do this...
  # assert !contact_autocomplete_div.visible?

  $ie.text_field(:id, field_id).set(type_string)
  #have to manually fire event to get div to show
  $ie.text_field(:id, field_id).fireEvent("onkeydown")

  #give the autocomplete some time to come up, just in case
  sleep 2

  if should_match
    #now visible
    assert contact_autocomplete_div.visible?
    assert_match Regexp.new(match_string), contact_autocomplete_div.text.strip
  else
    assert !contact_autocomplete_div.visible? || !Regexp.new(match_string).match(contact_autocomplete_div.text.strip)
  end
end

class Test::Unit::TestCase
  #MGS- helper function to login as existingbob
  #MGS TODO - reorg
  def login_user(username = "bob", password = "atest")
    gotoPage("users/login")

    $ie.text_field(:id, "login").set(username)
    $ie.text_field(:id, "password").set(password)
    $ie.button(:id, "login-button").click

    #try to go to user's schedule details page
    gotoPage("planners/schedule_details")

    #if we made it there we must be logged in
    assert_equal($ie.url, $htmlRoot + "planners/schedule_details")
  end
end

#MGS- for some reason this isn't supported by default in Watir
class Watir::Element
  def visible?
    elm = @o;
    display = true
    while(elm && elm.tagName != 'BODY')
      style = elm.invoke("style");
      if style.invoke("display") == 'none' || style.invoke("visibility") == 'hidden'
        display = false
        break
      end
      elm = elm.parentElement
    end
    display
  end
end


start_ie_with_logger
set_local_dir