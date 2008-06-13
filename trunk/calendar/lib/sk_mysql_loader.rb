class MysqlLoader
  @@our_mysql_loaded = false

  def self.load_our_mysql
    if !@@our_mysql_loaded
      require 'sk_mysql'
      
      @@our_mysql_loaded = true
    end
  end
end