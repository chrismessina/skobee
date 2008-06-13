require File.dirname(__FILE__) + '/../test_helper'

class UserAgentTest < Test::Unit::TestCase
  
  fixtures :users, :user_contacts, :planners, :planners_plans, :places, :plans, :sessions, :user_atts, :emails
   
  def setup
    @controller = UsersController.new
    @request, @response = ActionController::TestRequest.new, ActionController::TestResponse.new
    @request.host = "localhost"
    
    @emails = ActionMailer::Base.deliveries
    @emails.clear
  end
  
  def test_reminders
    User.send_reminders
    assert_equal 7, @emails.size, 'Wrong number of confirmation emails sent'    
    #MES- Note that test_reminder unit test tests the format of the reminders
  end
  
  def test_update_contacts
    #MES- Before updating, friend_1_of_user does NOT
    # consider user_with_friends a contact
    usr1 = users(:friend_1_of_user)
    usr2 = users(:user_with_friends)
    assert !usr1.contacts.include?(usr2), 'User friend_1_of_user should NOT consider user user_with_friends a contact at the start of the test'
    
    #MES- And user user_with_friends should have 0 for the
    # connection count to user friend_1_of_user
    assert_equal 0, usr2.contacts.find(usr1.id).connections.to_i, 'User user_with_friends should be connected to user friend_1_of_user with a connection count of 0 at the start of the test'
    
    #MES- Perform the update
    User.update_contacts
    
    #MES- Reload the users- the relation SHOULD be there now
    usr1 = User.find(users(:friend_1_of_user).id)
    usr2 = User.find(users(:user_with_friends).id)
    assert usr1.contacts.include?(usr2), 'User friend_1_of_user should consider user user_with_friends a contact after update'
    
    #MES- Now user user_with_friends should have 2 for the
    # connection count to user friend_1_of_user
    assert_equal 2, usr2.contacts.find(usr1.id).connections.to_i, 'User user_with_friends should be connected to user friend_1_of_user with a connection count of 2 after update'
  end
    
  def test_cleanup_sessions
    #MES- Cleaning up sessions should delete sessions that are older
    # than an hour, but leave others
    assert_equal 2, User.connection.select_all('SELECT COUNT(*) AS CT FROM sessions')[0]['CT'].to_i, 'Test should start with 2 sessions'
    User.cleanup_sessions    
    assert_equal 1, User.connection.select_all('SELECT COUNT(*) AS CT FROM sessions')[0]['CT'].to_i, 'Test should end with 1 session'
  end
  
  def test_x_master_agents
    #MES- TODO: It's not clear why, but this test MUST run after the other
    # tests in this suite.  If it runs before the other tests, it "corrupts" the
    # data in the system, and the other tests fail.  I'd think that the fixtures
    # should reload all relevant data, but it doesn't seem like that's working
    # correctly.
    # To work around, I renamed this function to "test_x_..." to have it sort at
    # the end, and therefore run last.
    #MES- Test the master agents- the agents that wrap up other agents
    User.frequent_tasks
    User.nightly_tasks
  end

end