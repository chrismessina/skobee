desc "Load fixtures data into the development database"
task :load_development_fixtures => :environment do
   load_fixtures_helper :development, 'db/fixtures'
end

desc "Load fixtures data into the development database"
task :ld => :load_development_fixtures

desc "Load fixtures data into the test database"
task :load_test_fixtures => :environment do
   load_fixtures_helper :test, 'test/fixtures'
end

desc "Load dumped fixtures data into the development database"
task :load_dumped_fixtures_to_development => :environment do
   load_fixtures_helper :development, 'db/dumped_fixtures'
end

desc "Load dumped fixtures data into the development database"
task :ldd => :load_dumped_fixtures_to_development

desc "Load the scale testing fixtures from the scale_fixtures folders"
task :lds => :environment do
   load_fixtures_helper(:production, "db/scale_fixtures")
end

def load_fixtures_helper(env, path)
   require 'active_record/fixtures'
   ActiveRecord::Base.establish_connection(env)
   Fixtures.create_fixtures(path,
       ActiveRecord::Base.configurations[:fixtures_load_order])
end