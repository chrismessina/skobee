#MES- From http://blog.craz8.com/articles/2005/10/25/rails-application-testing-in-damage-control
class Rake::Task
  def remove_prerequisite(task_name)
    name = task_name.to_s
    @prerequisites.delete(name)
  end
end

class Rake::Application
  #MES- Delete the named task, so that we can replace it
  def delete_task(task_name)
    @tasks.delete(task_name)
  end
end

Rake::Task['test:units'.to_sym].remove_prerequisite('db:test:prepare')
Rake::Task['test:functionals'.to_sym].remove_prerequisite('db:test:prepare')

#MES- Delete the default task- we want OUR default, which calls things in OUR way
Rake.application.delete_task('default')

desc "Run all the tests"
task :default do
  Rake::Task.run_ordered [
    :test_units,
    :test_functional,
    :test_agent]
end

desc "Run the agent tests"
Rake::TestTask.new(:test_agent => []) do |t|
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
  res = `rake test_units test_functional_with_xhtml_validation test_agent`
  if 0 != $?.exitstatus
    puts res
    mail = IO.popen("mail -s 'Nightly test FAILED' developers@skobee.com", "w+")
    mail.puts res
    mail.puts "\d"
    mail.puts "\d"
    mail.close_write
    #MES- Since the test failed, we want to exit.  We do NOT want any dependent tasks to run.
    raise "Test failed, aborting Rake tasks"
  else
    mail = IO.popen("mail -s 'Nightly test SUCCEEDED' developers@skobee.com", "w+")
    mail.puts res
    mail.puts "\d"
    mail.puts "\d"
    mail.close_write
  end
end

task :repeat do
  Rake::Task.run_multiple(50, :test_units)
end

desc "Run the unit, functional, and agent tests and generate coverage stats.  You must have the coverage gem installed for this to work."
task :test_coverage do
  Rake::Task[:prepare_test_database].invoke
  #MGS- exclude list is a comma-delimited list of regexp's
  exclude = %w(.*test.* boot.rb environment.rb user_environment.rb routes.rb json.rb output_compression.rb assert_valid_markup.rb).join(',')
  fl = FileList.new.include('test/unit/**/*_test.rb', 'test/functional/**/*_test.rb', 'test/agent/**/*_test.rb')
  `rcov #{fl} --exclude #{exclude}`
end


desc "Run the functional tests in test/functional and validate the XHTML"
task :test_functional_with_xhtml_validation do |t|
  ENV['VALIDATE_XHTML'] = 'true'
  Rake::Task[:test_functional].invoke
end

