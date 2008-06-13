require File.dirname(__FILE__) + '/watir_test_helper'

class PlanTest < Test::Unit::TestCase
    include Watir

    def setup
      super

    end

    def gotoPage( a )
       $ie.goto($htmlRoot + a)
    end


    def test_place_comments
      login_user("existingbob")
      #goto place
      gotoPage("places/show/1")

      add_comment_div = $ie.div(:id, "comment-add")
      assert !add_comment_div.visible?
      $ie.link(:id, "add-comment").click

      assert add_comment_div.visible?

      #now hit cancel
      $ie.link(:id, "cancel-comment").click
      #give the ajax some time to render
      sleep 1

      assert !add_comment_div.visible?

      #creating first comment
      $ie.link(:id, "add-comment").click

      $ie.text_field(:id, "comment_tb").set("scrubby rise")
      $ie.link(:id, "save-comment").click
      sleep 1

      assert !add_comment_div.visible?

      assert $ie.contains_text("scrubby rise")
      #assert $ie.contains_text("Created by existingbob")


      #creating second comment
      $ie.link(:id, "add-comment").click

      $ie.text_field(:id, "comment_tb").set("this place doesn't have the borracho burrito")
      $ie.link(:id, "save-comment").click
      sleep 1

      assert !add_comment_div.visible?

      #make sure the first comment is still there
      assert $ie.contains_text("scrubby rise")
      #assert $ie.contains_text("Created by existingbob")
      # and check for the second
      assert $ie.contains_text("this place doesn't have the borracho burrito")
      #assert $ie.contains_text("Created by existingbob")

      sleep 2

      comment_id = $ie.link(:text, "Edit").id
      comment_id.slice!("edit-comment-")

      #now edit the first comment
      $ie.link(:text, "Edit").click

      #change the text of this comment
      $ie.text_field(:name, "comment_edit_tb#{comment_id}").set("cafe lo cubano")
      $ie.link(:id, "save-comment#{comment_id}").click


      sleep 2

      #make sure the old text isnt there
      assert !$ie.contains_text("this place doesn't have the borracho burrito")
      assert $ie.contains_text("scrubby rise")
      assert $ie.contains_text("cafe lo cubano")

      #now try to delete the first comment
      startClicker("OK")
      $ie.link(:text, "Delete").click
      sleep 2

      #make sure the old text isnt there
      assert $ie.contains_text("scrubby rise")
      assert !$ie.contains_text("cafe lo cubano")
      assert !$ie.contains_text("this place doesn't have the borracho burrito")

    end

    def test_plan_comments
      login_user("existingbob")
      #goto place
      gotoPage("plans/show/12")

      add_comment_div = $ie.div(:id, "change-add")
      assert !add_comment_div.visible?
      $ie.link(:id, "add-change").click

      assert add_comment_div.visible?

      #now hit cancel
      $ie.link(:id, "cancel-change").click
      #give the ajax some time to render
      sleep 2

      assert !add_comment_div.visible?

      #creating first comment
      $ie.link(:id, "add-change").click

      $ie.text_field(:id, "change_tb").set("scrubby rise")
      $ie.link(:id, "save-change").click
      sleep 2

      assert $ie.contains_text("scrubby rise")
      assert $ie.contains_text("existingbob says")


      #creating second comment
      $ie.link(:id, "add-change").click

      $ie.text_field(:id, "change_tb").set("this place doesn't have the borracho burrito")
      $ie.link(:id, "save-change").click
      sleep 2


      #make sure the first comment is still there
      assert $ie.contains_text("scrubby rise")
      # and check for the second
      assert $ie.contains_text("this place doesn't have the borracho burrito")

      comment_id=""
      $ie.links.each do|l|
        if l.id.include? "edit-change"
          comment_id = l.id
          comment_id.slice!("edit-change-")
          break
        end
      end

      #now edit the first comment
      $ie.link(:id, "edit-change-#{comment_id}").click

      sleep 2

      #change the text of this comment
      $ie.text_field(:name, "change_edit_tb#{comment_id}").set("cafe lo cubano")
      $ie.link(:id, "save-change#{comment_id}").click

      sleep 3

      #make sure the old text isnt there
      assert $ie.contains_text("this place doesn't have the borracho burrito")
      assert $ie.contains_text("cafe lo cubano")
      assert !$ie.contains_text("scrubby rise")


      #now try to delete the first comment
      startClicker("OK")
      $ie.link(:text, "Delete").click
      sleep 3

      #make sure the old text isnt there
      assert !$ie.contains_text("this place doesn't have the borracho burrito")
      assert $ie.contains_text("cafe lo cubano")
      assert !$ie.contains_text("scrubby rise")

    end

end
