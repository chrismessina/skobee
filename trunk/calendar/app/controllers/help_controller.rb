class HelpController < ApplicationController

  def navigate
    #MGS- simple handler for navigation redirects
    redirect_to "/help/#{params[:change_section]}"
  end

  def comments_html_guide
    #MGS- make sure the popup comment help renders without a layout
    render_without_layout()
  end
end
