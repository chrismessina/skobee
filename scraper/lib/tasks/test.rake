desc "Run all the tests on a fresh test database"
task :default => [ :test_units, :test_functional, :test_agent ]


desc "Run the agent tests in test/agent"
Rake::TestTask.new(:test_agent => [ :prepare_test_database ]) do |t|
  t.libs << "test"
  t.pattern = 'test/agent/**/*_test.rb'
  t.verbose = true
end



desc "Start webrick with development environment on Unix"
task :start_development_webserver_unix do
  #MES- Kill any running WEBrick server- this could fail if there isn't one running (but we don't care)
  `ps aux | grep 'ruby #{File.join(File.dirname(__FILE__), '..', '..', 'script', 'server')}' | egrep -v grep | awk '{print $2}' | xargs kill -9`
  #MES- Restart the WEBrick server
  system "nohup ruby #{File.join(File.dirname(__FILE__), '..', '..', 'script', 'server')} --environment=development &"
end


desc "Start webbrick with test environment"
task :start_test_webserver do
    sh "start ruby #{File.join(File.dirname(__FILE__), '..', '..', 'script', 'server')} --environment=test"
    sleep 7  #pause for a few seconds to allow WEBrick to start up
end


desc "Run the watir tests in test/watir"
Rake::TestTask.new("test_watir") { |t|
  t.libs << "test"
  t.pattern = 'test/watir/**/*_test.rb'
  t.verbose = true
}


desc "Load the test fixtures, start the web server in the test environment, and run the watir tests"
task :run_watir_tests => [ :load_test_fixtures, :start_test_webserver, :test_watir ]


desc "Update code, run tests, start dev server [on unix]"
task :update_test_run_unix do | t |
	Rake::Task.run_ordered [
		:get_latest_source, 
		:create_db, 
		:run_test_notify_unix]
end


desc "Run all tests.  Send email notification indicating success or failure.  Email integration is Unix specific."
task :run_test_notify_unix do
  #MES- This is a special task, since we want to send an email
  #  if the tests fail.  I don't see an easy way in Rake to
  #  tell if a task failed, so we'll shell it and capture
  #  the output.
  res = `rake default`
  if 0 != $?.exitstatus
    puts res
    mail = IO.popen("mail -s 'Nightly test FAILED' michaels@skobee.com,marks@skobee.com,kavins@skobee.com", "w+")
    mail.puts res
    mail.puts "\d"
    mail.puts "\d"
    mail.close_write
    #MES- Since the test failed, we want to exit.  We do NOT want any dependent tasks to run.
    raise "Test failed, aborting Rake tasks"
  else
    mail = IO.popen("mail -s 'Nightly test SUCCEEDED' michaels@skobee.com,marks@skobee.com,kavins@skobee.com", "w+")
    mail.puts res
    mail.puts "\d"
    mail.puts "\d"
    mail.close_write
  end
end

task :repeat do
	Rake::Task.run_multiple(50, :test_units)
end
