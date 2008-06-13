desc "Get the latest source code from Subversion"
task :get_latest_source do
  `svn update`
end