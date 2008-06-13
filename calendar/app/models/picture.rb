#---
# Excerpted from "Agile Web Development with Rails"
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com for more book information.
#---

begin 
  require 'RMagick' 
  RMAGICK_SUPPORTED = true 
rescue 
  RMAGICK_SUPPORTED = false 
end 


class Picture < ActiveRecord::Base
  has_and_belongs_to_many :users
  belongs_to :original, :class_name => 'Picture', :foreign_key => 'original_id'

  #KS- the maximum number of pictures allowed
  MAX_NUM_PICS = 9
  
  #KS- the number of pictures in an image set (thumbnail, medium, full size)
  NUM_PICS_IN_IMAGE_SET = 3
  
  #KS- constants for primary / not primary
  PRIMARY = 0
  NOT_PRIMARY = 1
  
  #KS- constants for picture size
  SIZE_THUMBNAIL = 0
  SIZE_MEDIUM = 1
  SIZE_FULL = 2
           
  #MES- TODO: We may want to delay loading the data column- loading the data
  # just to get info like the extension might get expensive.
           
  THUMBNAIL_HEIGHT = 48.0
  THUMBNAIL_WIDTH = 48.0
  
  MEDIUM_HEIGHT = 115.0
  MEDIUM_WIDTH = 115.0
  
  MAX_HEIGHT = 640.0
  MAX_WIDTH = 480.0
  
  
  MAX_IMAGE_SIZE = 1 * 1024 * 1024
  
  #KS- set the width and height for a picture
  def set_dimensions!
    if RMAGICK_SUPPORTED
      #MES- Turn the blob into an ImageMagick object
      img = Magick::Image.from_blob(data).first
      if img.nil?
        raise "Error: could not get imagemagick image from picture #{self.id}'s data"
      end
      
      #KS- grab width & height and save them
      self.height = img.rows
      self.width = img.columns
    end
  end
           
  def picture=(picture_field)
    self.name = base_part_of(picture_field.original_filename)
    self.extension = File.extname(self.name)
    self.content_type = picture_field.content_type.chomp
    self.data = picture_field.read
  end
  
  #MES- We store the data as a Base64 encoded string, to make backup/restore easier
  def data=(data)
    enc = data.nil? ? data : Base64.encode64(data)
    write_attribute(:data, enc)
  end
  
  def data
    res = read_attribute(:data)
    res.nil? ? res : Base64.decode64(res)
  end
  
  def validate
    #MES- Check that the data isn't too big
    if MAX_IMAGE_SIZE < data.length
      errors.add_to_base "File is too large- maximum size is #{MAX_IMAGE_SIZE} bytes"
    end

    #MES- Check the file extension and MIME type.
    # NOTE: We only check the MIME type if the extension is good.  If the
    # extension is bad, it's confusing to tell users about problems with the
    # MIME type, as most users don't know what a MIME type is.
    if !extension.downcase.match(/^\.(gif|jpeg|jpg|bmp)$/)
      errors.add_to_base "You may only upload image files with these extensions: gif, jpeg, jpg, bmp"
    else
      if !content_type.downcase.match(/^image\/(gif|jpeg|pjpeg|png|bmp)$/)
        errors.add_to_base "You may only upload pictures with these MIME types: image\\gif, image\\jpeg, image\\pjpeg, image\\bmp"
      end
      
      #MES- NOTE: We USED to check that the MIME type returned by RMagick matched the 
      # MIME type as reported by the upload.  However, these don't match in a lot of
      # legitimate circumstances (e.g. you upload a .bmp file, the browser reports
      # 'image/bmp', but RMagick report 'image/x-bmp'.)
      # I removed the check.
    end
  
    #MES- Check that the blob we contain is an image
    if RMAGICK_SUPPORTED
      begin
        img = Magick::Image.from_blob(data).first
        #MES- Try to get the type- this will throw if it's not an image
        img.mime_type
      rescue
        #MES- If we get an exception converting it to an image, then it's not good
        errors.add_to_base "Image format is not recognized"
      end
    end
  end
  
  def load_from_file(filepath)
    #MES- Set the properties of this Picture object based on the file
    
    #MES- Convert backslashes to forward slashes- the Ruby file manipulation
    # functions work on forward slashes
    filepath.sub!('\\', '/')
    
    #MES- We can't do this if we can't use RMagick
    raise "Error in Picture#load_from_file: RMagick not installed!" if !RMAGICK_SUPPORTED
    
    #MES- Load the file in RMagick to get the MIME type
    img_lst = Magick::ImageList.new(filepath)
    self.content_type = img_lst.first.mime_type
    
    #MES- Set the name and file extension, which we get from filepath
    filename = File.basename(filepath)
    self.name = base_part_of(filename)
    self.extension = File.extname(self.name)
    
    #MES- Finally, set the data
    self.data = img_lst.to_blob # IO.read(filepath)
  end
  
  #KS- deletes all pictures that are part of the set of the passed in picture.
  def self.delete_image_set(old_image_id, user)
    #KS- get fullsize if this isn't the fullsize
    old_image = Picture.find(old_image_id)
    
    #KS- error if old_image wasn't found
    raise "Error: picture #{old_image_id} not found" if old_image.nil?

    fullsize = old_image.original_or_this
    
    #KS- if the pic is primary, blow away entries in the users table
    if user.primary?(fullsize)
      #KS- take the image out of the user table
      user.thumbnail = nil
      user.medium_image = nil
      user.image = nil
      user.save!
    end
    
    #KS- go through each of the user's images, delete any that have fullsize marked
    #as their original
    user.pictures.each{ |pic|
      if !pic.original.nil? && pic.original == fullsize
        delete_from_cache_and_destroy(pic.id)
      end
    }
    
    #KS- delete the fullsize
    delete_from_cache_and_destroy(fullsize.id)
  end
  
  #KS- delete the image from the database and disk. this expects the id of a thumbnail
  def self.delete_from_cache_and_destroy(old_image_id)
    #MES- Was there an image to act on?
    if !old_image_id.nil?
      begin
        old_image = Picture.find(old_image_id)
      
        #MES- We manually construct the path to the relevant files- is there a more
        # automated way to do this?
        imagefilename = File.join('.', 'public', 'pictures', 'show', old_image.id.to_s + old_image.extension)
        File.delete(imagefilename) if File.exists?(imagefilename)
        old_image.destroy
      rescue
        #MES- Ignore any errors- the item might not exist, or it might not be in the cache
      end
    end
  end

  def base_part_of(file_name)
    name = File.basename(file_name)
    name.gsub(/[^\w._-]/, '')
  end
  
  #KS- resize THIS picture and save! it. maintain aspect ratio
  def resize_and_save!(height = MAX_HEIGHT, width = MAX_WIDTH, validate = true)
    #KS- Only do thumbnailing if the Image Magick library can be loaded.
    # This is to make setup easier for other developers- they are not
    # required to have Image Magick.
    # More information on Image Magick is available at 
    # http://studio.imagemagick.org/RMagick/doc/usage.html
    if RMAGICK_SUPPORTED
      #MES- Turn the blob into an ImageMagick object
      img = Magick::Image.from_blob(data).first
      if img.nil?
        logger.info "Failed to resize image #{self.name}- unable to create RMagick wrapper for image"
        return nil
      end
      
      #MES- Shrink the image
      self.data = img.change_geometry("#{MAX_WIDTH}x#{MAX_HEIGHT}"){ |cols, rows, img| 
        if img.rows > rows || img.columns > cols
          img.resize!(cols, rows)
        else
          img
        end
      }.to_blob
    end
    
    successful = save_with_validation(validate)
    raise "Error: picture #{self.id} not saved properly" if !successful
  end
  
  #KS- resize the data and return it without saving. force the resized image to the dimensions specified
  #by cropping the image as necessary
  def do_resize(height = THUMBNAIL_HEIGHT, width = THUMBNAIL_WIDTH)
    #MES- Only do thumbnailing if the Image Magick library can be loaded.
    # This is to make setup easier for other developers- they are not
    # required to have Image Magick.
    # More information on Image Magick is available at 
    # http://studio.imagemagick.org/RMagick/doc/usage.html
    if RMAGICK_SUPPORTED
      #MES- Turn the blob into an ImageMagick object
      img = Magick::Image.from_blob(data).first
      if img.nil?
        logger.info "Failed to resize image #{self.name}- unable to create RMagick wrapper for image"
        return nil
      end
      
      #MES- Shrink the image
      return img.crop_resized(width, height)
    else
      return nil
    end
  end
  
  #KS- resize this image to thumbnail size
  def create_thumbnail
    return create_resized_pic(THUMBNAIL_HEIGHT, THUMBNAIL_WIDTH, SIZE_THUMBNAIL)
  end
  
  #KS- resize this image to medium pic size
  def create_medium
    return create_resized_pic(MEDIUM_HEIGHT, MEDIUM_WIDTH, SIZE_MEDIUM)
  end
  
  #KS- return the original (this is the original if this's original is nil)
  def original_or_this
    if original.nil?
      return self
    else
      return self.original
    end
  end
  
  private
  
  def create_resized_pic(height, width, type)
    resized = do_resize(height, width)
    
    if resized.nil?
      return nil
    else
      return Picture.create(
        :name => self.name, 
        :extension => self.extension, 
        :content_type => self.content_type, 
        :data => resized.to_blob, 
        :size_type => type,
        :original => self)
    end
  end
end
