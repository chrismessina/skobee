require File.dirname(__FILE__) + '/watir_test_helper'

class LoginTest < Test::Unit::TestCase
    include Watir

    def gotoPage( a )
       $ie.goto($htmlRoot + a)
    end

    # is this correct?
    def test_login_form_render
      gotoPage("users/login")
      assert($ie.contains_text("Please login"))
      assert($ie.button(:id, "login-button").exists?)   #login button
      assert($ie.text_field(:id, "login").exists?)   #username input
      assert($ie.text_field(:id, "password").exists?)   #password input
      assert($ie.checkbox(:id, "remember_me").exists?)   #remember me checkbox
    end


    def test_login_logout_existingbob
      gotoPage("users/login")

      $ie.text_field(:id, "login").set("existingbob")
      $ie.text_field(:id, "password").set("atest")
      $ie.button(:id, "login-button").click

      gotoPage("planners/schedule_details/2")
      assert_equal($ie.url, $htmlRoot + "planners/schedule_details/2")

      assert($ie.contains_text("Friends' Plans"))
      assert($ie.contains_text("Friends' Places"))


      $ie.link(:text, "Log out").click

      #should be redirected back to the login page
      assert_equal($ie.url, $htmlRoot + "users/login")
      assert($ie.contains_text("login"))
    end


end