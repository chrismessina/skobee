require File.dirname(__FILE__) + '/../test_helper'

class PictureTest < Test::Unit::TestCase
  fixtures :users

  def test_load_from_file
    pict = Picture.new
    pict.load_from_file(File.dirname(__FILE__) + '/../data/smedberg.jpg')
    
    assert_equal 'smedberg.jpg', pict.name
    assert_equal '.jpg', pict.extension
    assert_equal 'image/jpeg', pict.content_type
  end
    
  def test_create_thumbnail
    #KS- make sure it does the shrinking properly
    uploaded_pic = uploaded_jpeg(File.dirname(__FILE__) + '/../data/large_image.jpg', 'large_image.jpg')
    pic = Picture.new({'picture' => uploaded_pic, 'size_type' => Picture::SIZE_FULL})
    thumbnail = pic.create_thumbnail
    img = Magick::Image.from_blob(thumbnail.data).first
    assert_equal Picture::THUMBNAIL_HEIGHT, img.rows
    assert_equal Picture::THUMBNAIL_WIDTH, img.columns
    
    #KS- make sure it blows it up if the given pic is smaller
    uploaded_pic = uploaded_jpeg(File.dirname(__FILE__) + '/../data/tiny_smedberg.jpg', 'tiny_smedberg.jpg')
    pic = Picture.new({'picture' => uploaded_pic, 'size_type' => Picture::SIZE_FULL})
    same_size_pic = pic.create_thumbnail
    img = Magick::Image.from_blob(same_size_pic.data).first
    assert_equal Picture::THUMBNAIL_HEIGHT, img.rows
    assert_equal Picture::THUMBNAIL_WIDTH, img.columns
  end
    
  def test_create_medium
    #KS- make sure it does the shrinking properly
    uploaded_pic = uploaded_jpeg(File.dirname(__FILE__) + '/../data/large_image.jpg', 'large_image.jpg')
    pic = Picture.new({'picture' => uploaded_pic, 'size_type' => Picture::SIZE_FULL})
    thumbnail = pic.create_medium
    img = Magick::Image.from_blob(thumbnail.data).first
    assert_equal Picture::MEDIUM_HEIGHT, img.rows
    assert_equal Picture::MEDIUM_WIDTH, img.columns
    
    #KS- make sure it blows it up if the given pic is smaller
    uploaded_pic = uploaded_jpeg(File.dirname(__FILE__) + '/../data/tiny_smedberg.jpg', 'tiny_smedberg.jpg')
    pic = Picture.new({'picture' => uploaded_pic, 'size_type' => Picture::SIZE_FULL})
    same_size_pic = pic.create_medium
    img = Magick::Image.from_blob(same_size_pic.data).first
    assert_equal Picture::MEDIUM_HEIGHT, img.rows
    assert_equal Picture::MEDIUM_WIDTH, img.columns
  end
  
  def test_resize_and_save
    #KS- make sure it resizes the image if it's bigger than the max dimensions
    uploaded_pic = uploaded_jpeg(File.dirname(__FILE__) + '/../data/large_image.jpg', 'large_image.jpg')
    pic = Picture.new({'picture' => uploaded_pic, 'size_type' => Picture::SIZE_FULL})
    pic.resize_and_save!
    img = Magick::Image.from_blob(pic.data).first
    assert_equal Picture::MAX_WIDTH, img.columns
    assert img.rows <= Picture::MAX_HEIGHT
    
    #KS- make sure it doesn't resize the image if it's smaller than the max dimensions
    uploaded_pic = uploaded_jpeg(File.dirname(__FILE__) + '/../data/tiny_smedberg.jpg', 'tiny_smedberg.jpg')
    pic = Picture.new({'picture' => uploaded_pic, 'size_type' => Picture::SIZE_FULL})
    pic.resize_and_save!
    img = Magick::Image.from_blob(pic.data).first
    assert_equal 24, img.columns
    assert_equal 24, img.rows
  end
end
