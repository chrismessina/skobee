require File.dirname(__FILE__) + '/../test_helper'

class EmailTest < Test::Unit::TestCase
  fixtures :emails

  #KS- confirming an email should NO LONGER blow away any other emails with the same
  #address
  def test_confirm_does_not_blow_away_duplicates
    #KS- make sure there are 3 emails with the same address
    emails = Email.find(:all, :conditions => [ "address = :address", { :address => "unconfirmed@skobee.com" } ])
    assert_equal 3, emails.length
    assert_equal 1, emails.find_all{|email| email.user_id == 2 && email.confirmed == Email::UNCONFIRMED}.length
    assert_equal 1, emails.find_all{|email| email.user_id == 3 && email.confirmed == Email::UNCONFIRMED}.length
    assert_equal 1, emails.find_all{|email| email.user_id == 4 && email.confirmed == Email::UNCONFIRMED}.length
    
    #KS- confirm one of them
    emails[0].confirmed = 1
    emails[0].save
    
    #KS- make sure they're both still there (shouldn't delete unconfirmed ones anymore)
    emails = Email.find(:all, :conditions => [ "address = :address", { :address => "unconfirmed@skobee.com" } ])
    assert_equal 3, emails.length
    assert_equal 1, emails.find_all{|email| email.user_id == 2 && email.confirmed == Email::CONFIRMED}.length
    assert_equal 1, emails.find_all{|email| email.user_id == 3 && email.confirmed == Email::UNCONFIRMED}.length
    assert_equal 1, emails.find_all{|email| email.user_id == 4 && email.confirmed == Email::UNCONFIRMED}.length
  end
end
