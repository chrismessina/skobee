require File.dirname(__FILE__) + '/watir_test_helper'

class ContactsTest < Test::Unit::TestCase
    include Watir

    def setup
      super

    end

    def gotoPage( a )
       $ie.goto($htmlRoot + a)
    end

    def test_contacts_and_contacts_inverse
      #MGS- one big test that runs through contacts and contacts inverse
      login_user("friend_2_of_user")
      #goto place
      gotoPage("users/contacts_inverse")


      assert($ie.contains_text("user_with_friends_and_friends_cal"))
      assert($ie.contains_text("user_with_friends_and_private_cal"))
      assert($ie.contains_text("user_with_friends"))
    end

    def test_contact_search
      #MGS- one big test that runs through contacts and contacts inverse
      login_user("friend_2_of_user")
      #goto place
      gotoPage("users/contacts")

      #MGS- search for Bob
      $ie.text_field(:id, "q").set("Bo")
      $ie.link(:id, "search_sitebar_link").click

      assert_equal($ie.url, $htmlRoot + "users/search?q=Bo")
      assert($ie.contains_text("bob"))
      sleep 2

      assert($ie.contains_text("bob"))
    end
end