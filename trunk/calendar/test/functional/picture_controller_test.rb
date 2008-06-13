require File.dirname(__FILE__) + '/../test_helper'
require 'pictures_controller'

# Raise errors beyond the default web-based presentation
class PicturesController; def rescue_action(e) raise e end; end

class PicturesControllerTest < Test::Unit::TestCase
  fixtures :users, :pictures, :emails, :pictures_users

  def setup
    @controller = PicturesController.new
    @request, @response = ActionController::TestRequest.new, ActionController::TestResponse.new
    @request.host = "localhost"
  end  
  
  def test_delete
    login
  
    #KS- Post a picture
    pict = uploaded_jpeg(File.dirname(__FILE__) + '/../data/smedberg.jpg', 'smedberg.jpg')
    post :add_picture, :picture => { :file => pict }
    usr = users(:bob, :force)
    assert_equal 3, usr.pictures.length
    
    #KS- post another pic
    secondary_pic = uploaded_jpeg(File.dirname(__FILE__) + '/../data/judah.gif', 'judah.gif')
    post :add_picture, :picture => { :file => secondary_pic }
    assert_equal 6, usr.pictures(true).length
    
    #KS- get ahold of the thumbnail so we can call delete
    usr = users(:bob, :force)
    thumbnail = usr.thumbnail
    medium = usr.medium_image
    full = usr.image
    assert_not_nil thumbnail
    assert_not_nil medium
    assert_not_nil full
  
    #KS- make sure delete doesn't work with a get
    get :delete, :id => thumbnail.id
    usr = users(:bob, :force)
    assert_equal 'smedberg.jpg', usr.image.name
    assert_equal 'smedberg.jpg', usr.thumbnail.name

    #KS- delete the picture
    post :delete, :id => thumbnail.id

    #KS- make sure picture and thumbnail are set to the secondary pic
    usr = users(:bob, :force)
    assert_not_nil usr.thumbnail
    assert_not_nil usr.medium_image
    assert_not_nil usr.image
    assert usr.pictures.include?(usr.thumbnail)
    assert usr.pictures.include?(usr.medium_image)
    assert usr.pictures.include?(usr.image)
    assert thumbnail.id != usr.thumbnail.id
    assert medium.id != usr.medium_image.id
    assert full.id != usr.image.id
    assert_equal Picture::NUM_PICS_IN_IMAGE_SET, usr.pictures.length
    
    #KS- delete the remaining pic
    post :delete, :id => usr.thumbnail.id
    
    #KS- last pic was deleted so we should have a blank primary pic
    usr = users(:bob, :force)
    assert_nil usr.image
    assert_nil usr.medium_image
    assert_nil usr.thumbnail
  end

  def test_disallowed_picture
    login
    #MES- Post a tiff picture
    ct = Picture.count
    pict = uploaded_tiff(File.dirname(__FILE__) + '/../data/cramps.tif', 'cramps.tif')
    post :add_picture, :picture => { :file => pict }
    #MES- Should NOT have made a picture
    usr = users(:bob, :force)
    assert_nil usr.image
    assert_nil usr.thumbnail
    #MES- Should have displayed a flash error
    assert_tag :tag => 'div', :content => /You may only upload image files with these extensions/

    #MES- Post a png picture
    pict = uploaded_png(File.dirname(__FILE__) + '/../data/french_nationality.png', 'french_nationality.png')
    post :add_picture, :picture => { :file => pict }
    #MES- Should NOT have made a picture
    usr = users(:bob, :force)
    assert_nil usr.image
    assert_nil usr.thumbnail
    #MES- Should have displayed a flash error
    assert_tag :tag => 'div', :content => /You may only upload image files with these extensions/

    #MES- Post a very large picture
    pict = uploaded_jpeg(File.dirname(__FILE__) + '/../data/large_image.jpg', 'large_image.jpg')
    post :add_picture, :picture => { :file => pict }
    #MES- Should NOT have made a picture
    usr = users(:bob, :force)
    assert_nil usr.image
    assert_nil usr.thumbnail
    #MES- Should have displayed a flash error
    assert_tag :tag => 'div', :content => /File is too large/
  end
  
  def test_make_primary
    login
    
    #KS- add a picture (will be primary since none exist right now)
    pict = uploaded_jpeg(File.dirname(__FILE__) + '/../data/smedberg.jpg', 'smedberg.jpg')
    post :add_picture, :picture => { :file => pict }
    #MES- Should have made a picture and a thumbnail
    usr = users(:bob)
    assert_equal 'smedberg.jpg', usr.image.name
    assert_equal 'smedberg.jpg', usr.thumbnail.name
    
    #KS- add a second picture
    pict = uploaded_pjpeg(File.dirname(__FILE__) + '/../data/holdingjesus_pjpeg.jpg', 'holdingjesus_pjpeg.jpg')
    post :add_picture, :picture => { :file => pict }
    #MES- Should have made a picture and a thumbnail
    usr = users(:bob, :force)
    thumb = usr.pictures.detect{ |pic| pic.name == 'holdingjesus_pjpeg.jpg' && pic.size_type == Picture::SIZE_THUMBNAIL }
    full = usr.pictures.detect{ |pic| pic.name == 'holdingjesus_pjpeg.jpg' && pic.size_type == Picture::SIZE_FULL }
    assert_not_nil thumb
    assert_not_nil full
    usr = users(:bob, :force)
    assert_not_equal usr.image.id, full.id
    assert_not_equal usr.thumbnail.id, thumb.id
    
    #KS- keep hold of the old primary pics
    old_primary = usr.image
    old_thumbnail = usr.thumbnail
    
    #KS- make the second picture primary
    post :make_primary, :id => thumb.id
    
    #KS- thumb and full should be primary now
    usr = users(:bob, :force)
    assert_equal usr.thumbnail.id, thumb.id
    assert_equal usr.image.id, full.id
  end

  def test_add_picture
    login
    #MES- Post a picture
    pict = uploaded_jpeg(File.dirname(__FILE__) + '/../data/smedberg.jpg', 'smedberg.jpg')
    post :add_picture, :picture => { :file => pict }
    #MES- Should have made a picture and a thumbnail
    usr = users(:bob)
    assert_equal 'smedberg.jpg', usr.image.name
    assert_equal 'smedberg.jpg', usr.medium_image.name
    assert_equal 'smedberg.jpg', usr.thumbnail.name

    #MES- Test that all allowed picture types actually work
    login
    #MES- image/pjpeg
    pict = uploaded_pjpeg(File.dirname(__FILE__) + '/../data/holdingjesus_pjpeg.jpg', 'holdingjesus_pjpeg.jpg')
    post :add_picture, :picture => { :file => pict }
    #MES- Should have made a picture and a thumbnail
    usr = users(:bob, :force)
    assert_not_nil usr.pictures.detect{ |pic| pic.name == 'holdingjesus_pjpeg.jpg' && pic.size_type == Picture::SIZE_THUMBNAIL }
    assert_not_nil usr.pictures.detect{ |pic| pic.name == 'holdingjesus_pjpeg.jpg' && pic.size_type == Picture::SIZE_FULL }

    #MES- image/bmp
    pict = uploaded_bmp(File.dirname(__FILE__) + '/../data/scar.bmp', 'scar.bmp')
    post :add_picture, :picture => { :file => pict }
    #MES- Should have made a picture and a thumbnail
    usr = users(:bob, :force)
    assert_equal 1, usr.pictures.select{ |pic| pic.name == 'scar.bmp' && pic.size_type == Picture::SIZE_THUMBNAIL }.length
    assert_equal 1, usr.pictures.select{ |pic| pic.name == 'scar.bmp' && pic.size_type == Picture::SIZE_FULL }.length

    #MES- image/gif
    pict = uploaded_gif(File.dirname(__FILE__) + '/../data/judah.gif', 'judah.gif')
    post :add_picture, :picture => { :file => pict }
    #MES- Should have made a picture and a thumbnail
    usr = users(:bob, :force)
    assert_equal 1, usr.pictures.select{ |pic| pic.name == 'judah.gif' && pic.size_type == Picture::SIZE_THUMBNAIL }.length
    assert_equal 1, usr.pictures.select{ |pic| pic.name == 'judah.gif' && pic.size_type == Picture::SIZE_FULL }.length
    
    #KS- make sure png doesn't work
    pict = uploaded_gif(File.dirname(__FILE__) + '/../data/french_nationality.png', 'french_nationality.png')
    post :add_picture, :picture => { :file => pict }
    #KS- there should be neither a picture nor a thumbnail
    usr = users(:bob, :force)
    assert_equal 0, usr.pictures.select{ |pic| pic.name == 'french_nationality.png' && pic.size_type == Picture::SIZE_THUMBNAIL }.length
    assert_equal 0, usr.pictures.select{ |pic| pic.name == 'french_nationality.png' && pic.size_type == Picture::SIZE_FULL }.length
  end
end