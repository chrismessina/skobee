require File.dirname(__FILE__) + '/../test_helper'
require 'tmail'

class EmailTest < Test::Unit::TestCase

  def test_plan_addresses
    #MES- Make an email address, and make an email that holds it
    email_address = EmailId.email_address_for_plan(123)
    email = TMail::Mail.new
    email.to = email_address
    #MES- Try to get the ID back out again
    id = EmailId.plan_id_from_email(email)
    assert_equal 123, id
  end
  
  def test_canonicalize_subject
    assert_equal 'base test', EmailId.canonicalize_subject('base test')
    assert_equal 'simple RE', EmailId.canonicalize_subject('Re: simple RE')
    assert_equal 'simple FW', EmailId.canonicalize_subject('fW: simple FW')
    assert_equal 'simple RE', EmailId.canonicalize_subject(' re: simple RE')
    assert_equal 'simple FW', EmailId.canonicalize_subject(' FW: simple FW')
    assert_equal 'simple RE', EmailId.canonicalize_subject(' rE:simple RE')
    assert_equal 'simple FW', EmailId.canonicalize_subject(' FW:simple FW')
    assert_equal 'double', EmailId.canonicalize_subject('RE: re: double')
    assert_equal 'double', EmailId.canonicalize_subject('Fw: FW: double')
    assert_equal 'middle RE: middle', EmailId.canonicalize_subject('rE: RE: middle RE: middle')
    assert_equal 'middle FW: middle', EmailId.canonicalize_subject('fW: FW: middle FW: middle')
    assert_equal 'mixed', EmailId.canonicalize_subject('RE:fw:mixed')
    assert_equal 'mixed', EmailId.canonicalize_subject('FW: RE:FW:mixed')
    assert_equal 'only RE: middle', EmailId.canonicalize_subject('only RE: middle')
  end
end