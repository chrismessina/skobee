#MES- From C:\ruby\lib\ruby\gems\1.8\gems\actionmailer-1.2.1\lib\action_mailer\base.rb
class ActionMailer::Base
  #KS- using a different logger from the standard, so that the email logging
  #goes into a different file
  ActionMailer::Base.logger = Logger.new("log/emails.log")
end