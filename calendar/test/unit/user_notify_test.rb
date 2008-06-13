require File.dirname(__FILE__) + '/../test_helper'

class UserNotifyTest < Test::Unit::TestCase

  fixtures :users, :plans, :planners, :planners_plans, :places, :emails, :plan_changes, :comments

  def setup
    @sent_emails = ActionMailer::Base.deliveries
    @sent_emails.clear
  end

##
# MGS- TODO Just a start on the unit tests for email
# Needed to have something in here to just test the new from
# addresses, but we need to do more checks in these unit tests.
##


  def test_signup
    user = users(:existingbob)
    UserNotify.deliver_signup(user, "http://www.skobee.com/users/signup")

    assert_equal 1, @sent_emails.length
    assert_equal UserSystem::CONFIG[:app_name], @sent_emails[0].from_addrs[0].name
  end

  def test_forgot_password
    user = users(:existingbob)
    UserNotify.deliver_forgot_password(user)

    assert_equal 1, @sent_emails.length
    assert_equal UserSystem::CONFIG[:app_name], @sent_emails[0].from_addrs[0].name
  end

  def test_friend_notification
    user_added_as_friend = users(:existingbob)
    user_adding_as_friend = users(:bob)
    UserNotify.deliver_friend_notification(user_added_as_friend, user_adding_as_friend)

    assert_equal 1, @sent_emails.length
    assert_equal UserSystem::CONFIG[:app_name], @sent_emails[0].from_addrs[0].name
    assert @sent_emails[0].body.match(/http:\/\/localhost\:3000\/users\/edit_notifications/)
  end

  def test_confirm_email
    user = users(:existingbob)

    UserNotify.deliver_confirm_email("existing.bob@skobee.com", user, "http://www.skobee.com/confirm_email")

    assert_equal 1, @sent_emails.length
    assert_equal UserSystem::CONFIG[:app_name], @sent_emails[0].from_addrs[0].name
  end

  def test_confirm_register
    user = users(:existingbob)

    UserNotify.deliver_confirm_register(user, "http://www.skobee.com/confirm_email")

    assert_equal 1, @sent_emails.length
    assert_equal UserSystem::CONFIG[:app_name], @sent_emails[0].from_addrs[0].name
  end

  def test_pending_delete
    user = users(:existingbob)

    UserNotify.deliver_pending_delete(user, "http://www.skobee.com/confirm_email")

    assert_equal 1, @sent_emails.length
    assert_equal UserSystem::CONFIG[:app_name], @sent_emails[0].from_addrs[0].name
  end

  def test_update_notification
    user = users(:existingbob)
    modifying_user = users(:user_with_contacts)
    change = plan_changes(:change_for_second_plan_for_place_stats)
    plan = plans(:second_plan_for_place_stats)

    UserNotify.deliver_update_notification(user, [change], plan, modifying_user)

    assert_equal 1, @sent_emails.length
    assert_equal "#{modifying_user.real_name} #{UserNotify::EMAIL_FROM_SUFFIX}", @sent_emails[0].from_addrs[0].name
    assert @sent_emails[0].body.match(/http:\/\/localhost\:3000\/users\/edit_notifications/)
  end

  def test_delete
    user = users(:existingbob)

    UserNotify.deliver_delete(user)

    assert_equal 1, @sent_emails.length
    assert_equal UserSystem::CONFIG[:app_name], @sent_emails[0].from_addrs[0].name
  end

  def test_invite_notification
    inviter = users(:bob)
    user = users(:existingbob)
    plan = plans(:second_plan_for_place_stats)

    UserNotify.deliver_invite_notification(inviter, user, plan)

    assert_equal 1, @sent_emails.length
    assert_equal "#{inviter.real_name} #{UserNotify::EMAIL_FROM_SUFFIX}", @sent_emails[0].from_addrs[0].name
    assert @sent_emails[0].body.match(/http:\/\/localhost\:3000\/users\/edit_notifications/)
    #MGS- assert that the description is in the email
    assert @sent_emails[0].body.match(/description for second plan for place stats/)
  end

  def test_unregistered_invite_notification
    inviter = users(:bob)
    user = users(:existingbob)
    plan = plans(:second_plan_for_place_stats)

    UserNotify.deliver_unregistered_invite_notification(inviter, user, plan, "http://www.skobee.com/register")

    assert_equal 1, @sent_emails.length
    assert_equal "#{inviter.real_name} #{UserNotify::EMAIL_FROM_SUFFIX}", @sent_emails[0].from_addrs[0].name
    #MGS- assert that the description is in the email
    assert @sent_emails[0].body.match(/description for second plan for place stats/)
  end

  def test_unregistered_remind
    inviter = users(:bob)
    user = users(:existingbob)
    plan = plans(:second_plan_for_place_stats)

    UserNotify.deliver_unregistered_remind(user, plan)

    assert_equal 1, @sent_emails.length
    assert_equal @sent_emails[0].from_addrs[0].name, UserSystem::CONFIG[:app_reminder_name]
    #MGS- assert that the description is in the email
    assert @sent_emails[0].body.match(/description for second plan for place stats/)
  end

  def test_remind
    user = users(:existingbob)
    plan = plans(:second_plan_for_place_stats)

    UserNotify.deliver_remind(user, plan)

    assert_equal 1, @sent_emails.length
    assert_equal UserSystem::CONFIG[:app_reminder_name], @sent_emails[0].from_addrs[0].name
    assert @sent_emails[0].body.match(/http:\/\/localhost\:3000\/users\/edit_notifications/)
  end

  def test_created_plan
    user = users(:existingbob)
    plan = plans(:second_plan_for_place_stats)

    UserNotify.deliver_created_plan(user, plan, false)

    assert_equal 1, @sent_emails.length
    assert_equal UserSystem::CONFIG[:app_name], @sent_emails[0].from_addrs[0].name
    #MGS- assert that the description is in the email
    assert @sent_emails[0].body.match(/description for second plan for place stats/)
  end

  def test_invite
    inviter = users(:existingbob)
    invitee = users(:bob)
    subject = "I'm inviting you to Skobee"
    main_body = "Lorem ipsum dolor sit amet, consectetuer adipiscing elit."

    UserNotify.deliver_invite(inviter, invitee, subject, main_body, "http://www.skobee.com/register")

    assert_equal 1, @sent_emails.length
    assert_equal "#{inviter.real_name} #{UserNotify::EMAIL_FROM_SUFFIX}", @sent_emails[0].from_addrs[0].name
  end

  def test_invite_new_user
    inviter = users(:existingbob)
    invitee = users(:bob)
    subject = "I'm inviting you to Skobee"
    main_body = "Lorem ipsum dolor sit amet, consectetuer adipiscing elit."

    UserNotify.deliver_invite_new_user(inviter, invitee, subject, main_body, "http://www.skobee.com/register")

    assert_equal 1, @sent_emails.length
    assert_equal "#{inviter.real_name} #{UserNotify::EMAIL_FROM_SUFFIX}", @sent_emails[0].from_addrs[0].name
    assert @sent_emails[0].body.match(/Lorem ipsum dolor sit amet/)
    assert @sent_emails[0].subject.match(/I'm inviting you to Skobee/)
  end

  def test_unregistered_fuzzy_expiry_reminder
    #MGS- adding unit tests
    user = users(:existingbob)
    plan = plans(:second_plan_for_place_stats)
    UserNotify.deliver_unregistered_fuzzy_expiry_reminder(user, plan)

    assert_equal 1, @sent_emails.length
    assert_equal @sent_emails[0].from_addrs[0].name, UserSystem::CONFIG[:app_reminder_name]
    #MGS- assert that the description is in the email
    assert @sent_emails[0].body.match(/description for second plan for place stats/)
  end

  def test_fuzzy_expiry_reminder
    #MGS- adding unit tests
    user = users(:existingbob)
    plan = plans(:second_plan_for_place_stats)
    UserNotify.deliver_fuzzy_expiry_reminder(user, plan)

    assert_equal 1, @sent_emails.length
    assert_equal @sent_emails[0].from_addrs[0].name, UserSystem::CONFIG[:app_reminder_name]
    #MGS- assert that the description is in the email
    assert @sent_emails[0].body.match(/description for second plan for place stats/)
  end

  def test_user_comment_notification
    #MGS- test for comments on user profiles
    user = users(:existingbob)
    modifying_user = users(:deletebob1)
    comment = comments(:user_comment_4)
    UserNotify.deliver_user_comment_notification(user, comment)

    assert_equal 1, @sent_emails.length
    assert_equal "#{modifying_user.real_name} #{UserNotify::EMAIL_FROM_SUFFIX}", @sent_emails[0].from_addrs[0].name
    #MGS- assert that the comment is in the email
    assert @sent_emails[0].body.match(/scrubby rise/)
    #MGS- check that the url is in the email
    assert @sent_emails[0].body.match("planners/show/#{user.planner.id}")
  end

end