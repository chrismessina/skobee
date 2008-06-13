desc "Create databases, or remake them if they already exist"
task :create_db do
  require(File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment'))
  #MES- It's not clear why the following require is needed, since we do a
  # require_gem above, but if it's not here, the call doesn't work.
  require 'db_structure'
  DBStructure::db_structure
end