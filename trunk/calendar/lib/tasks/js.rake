desc "Compress Skobee javascript files"
task :compress_js do
  JS_DIR = './public/javascripts'
  TEMPDIR = JS_DIR + '/tmp'

  files_to_compress = []
  Dir.foreach(JS_DIR) {|f| files_to_compress << f if !f.index(/.js$/).nil? }

  #MGS- make a temporary directory
  mkdir_p TEMPDIR

  files_to_compress.each do |file|
    original_file = File.join(JS_DIR, file)
    temp_file = File.join(TEMPDIR, file)

    #MGS- copy all of the js files to the temporary directory
    cp original_file, temp_file

    #MGS- now compress the scripts using the temp file as the source and replacing the original
    puts "Compressing #{original_file}"

    #MGS- if windows use the sun jvm, since that's what we have installed
    # for unix, use the gij vm, since that's what comes with redhat
    if RUBY_PLATFORM =~ /win32/i
      `java -jar ./lib/jar/custom_rhino.jar -c #{temp_file} > #{original_file} 2>&1`
    else
      `gij -jar ./lib/jar/custom_rhino.jar -c #{temp_file} > #{original_file} 2>&1`
    end

    #MGS-remove the temp file after compression
    rm temp_file
  end

  puts "Removing temporary directory..."
  rmdir TEMPDIR
end