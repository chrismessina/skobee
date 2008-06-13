class FeedbacksController < ApplicationController

  before_filter :login_required
  before_filter :must_be_admin

  def must_be_admin
    if !current_user.administrator?
      #MGS- user must be administrator for all actions except: comment_inappropriate_ajax
      redirect_back unless ("comment_inappropriate_ajax" == self.action_name)
    end
  end


  def index
    list
    render :action => 'list'
  end

  def list
    @feedback_pages, @feedbacks = paginate :feedbacks, :per_page => 100
  end

  def show
    @feedback = Feedback.find(params[:id])
  end

  def new
    @feedback = Feedback.new
  end

  def create
    @feedback = Feedback.new(params[:feedback])
    if @feedback.save
      flash[:notice] = 'Feedback was successfully created.'
      redirect_to :action => 'list'
    else
      render :action => 'new'
    end
  end

  def edit
    @feedback = Feedback.find(params[:id])
  end

  def update
    @feedback = Feedback.find(params[:id])
    if @feedback.update_attributes(params[:feedback])
      flash[:notice] = 'Feedback was successfully updated.'
      redirect_to :action => 'show', :id => @feedback
    else
      render :action => 'edit'
    end
  end

  def destroy
    Feedback.find(params[:id]).destroy
    redirect_to :action => 'list'
  end

  def comment_inappropriate_ajax
    #MGS- helper for making comments inappropriate
    id = params["inapp_id"]

    if params["places"]
      comment = Comment.find(id)
      body = comment.body
      parent = "place #{params["places"]}"
    elsif params["plans"]
      change = PlanChange.find(id)
      body = change.comment
      parent = "planchange #{id} on plan #{params["plans"]}"
    end

    @feedback = Feedback.new
    @feedback.url = params["request_url"]
    @feedback.user_id = current_user_id
    @feedback.feedback_type = Feedback::FEEDBACK_TYPE_INAPPROPRIATE
    @feedback.body = "INAPPROPRIATE COMMENT in #{parent}:\n#{body}"
    @feedback.stage = Feedback::FEEDBACK_STAGE_NEW
    @feedback.save
    #MGS- render nothing back; don't really need to do any super-fly error handling
    render(:nothing => true)
  end


end
