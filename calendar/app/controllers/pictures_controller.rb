class PicturesController < ApplicationController
  model   :picture
  session :off, :except => [ :add_picture, :delete, :make_primary, :full_display ]
  
  before_filter :login_required, :set_static_includes, :conditional_login_required, :except => [ :show, :full_display ]
  
  def add_picture
    @user = current_user
    @picture = nil
    @thumbnails = @user.thumbnails
    @mediums = @user.medium_images

    return if show_session_user_on_get

    #KS- if the user has the max number of pics, don't let them upload any more
    if current_user.pictures.length < Picture::MAX_NUM_PICS * Picture::NUM_PICS_IN_IMAGE_SET
      #MES- Save the picture info.
      if !@params['picture'].nil? && !@params['picture']['file'].nil?
        @picture = Picture.new({ 'picture' => @params['picture']['file'], 'size_type' => Picture::SIZE_FULL })
        if @picture.valid? && @picture.save
          #MES- Try to make a thumbnail
          thumb = @picture.create_thumbnail
          thumb.save!
          
          #KS- make a medium size pic
          medium = @picture.create_medium
          medium.save!
    
          #KS- resize the original pic
          @picture.resize_and_save!
          #KS- if the user doesn't have a primary pic, make this their primary pic
          if @user.image.nil?
            #MES- Put the picture into the user object
            @user.image = @picture
            @user.medium_image = medium
            @user.thumbnail = thumb
            @user.save!
            flash.now[:notice] = 'Your picture was uploaded successfully.'
          end
          
          #KS- put the pic and thumb into the user's collection of pics
          @user.pictures << @picture
          @user.pictures << medium
          @user.pictures << thumb
          @user.save!
          
          #MES- Reset the lists of images to show
          @thumbnails = @user.thumbnails
          @mediums = @user.medium_images
        end
      end
    else
      flash[:error] = "You can not have more than #{Picture::MAX_NUM_PICS} pictures at one time. Delete some pictures in order to upload another."
    end
  end
  
  def show
    #MES- Show the picture indicated by the ID
    pict = Picture.find(params[:id])
    
    #MES- Write the image to a file in the proper location
    filename = './public' + @request.request_uri.chomp('?')
    open(filename, 'wb') do | f |
      f.write pict.data
    end
    
    #MES- Redirect to this same URL- now that the picture is on disk, it'll be returned
    # faster by the web server
    #NOTE: This COULD cause the browser to be bumped from web server to web server, as the cache
    # gets filled up on all the web servers.  In practice, this probably won't result in too many
    # hops.
    redirect_to :action => 'show'
  end
  
  #KS- delete the given picture. currently this expects the id of a picture that is of SIZE_THUMBNAIL.
  def delete
    #KS- don't do anything unless the request was a POST
    if @request.method == :post
      picture = Picture.find(params['id'])
    
      #KS- destroy the thumbnail and original image
      Picture.delete_image_set(picture.id, current_user)
      
      #KS- need to force a reload of current_user to get the proper pictures array
      pics = current_user.pictures(true)
      
      #KS- if there are any pics left, set the primary pic for the user to one of those
      if !pics.nil? && pics.length > 0
        current_user.make_primary(pics[0])
      end
    end
      
    redirect_to :action => 'add_picture'
  end
  
  #KS- make the given picture primary for the current user. currently this expects the id of a picture that is of SIZE_THUMBNAIL.
  def make_primary
    picture = Picture.find(params['id'])
    user = current_user
  
    user.make_primary(picture)
   
    redirect_to :action => 'add_picture'
  end
  
  #KS- display a user's picture gallery
  def full_display
    @user = User.find(params[:user_id])
    
    if params[:active_pic_id].blank?
      @active_picture = @user.image
    else
      @active_picture = @user.pictures.detect{ |pic| pic.id == params[:active_pic_id].to_i }
    end
  end
  
  def set_static_includes
    @javascripts = [JS_SCRIPTACULOUS_SKOBEE_DEFAULT]
  end
end
