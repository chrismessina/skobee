function cancelCommentCommon(){
  editor_open = false;
  Element.hide($('comment-add'));
  $('comment_tb').value='';
  rowHover('plan_discuss_row', false, HOVER_TYPE_COMMENT);
}

function openCommentCommon(){
  editor_open = true;
  Element.show('comment-add');
}

function saveCommentCommon(controller){
  var action = '/' + controller + '/add_comment_ajax';
  editor_open = false;
  new Ajax.Updater('change-list', action,
    {method: 'post', asynchronous:true, evalScripts:true,
     parameters:Form.serialize(document.forms['comment-add-form']),
     onFailure:handleFail,
     onComplete: function(request){commentCallback(request);rowHover('plan_discuss_row', false, HOVER_TYPE_COMMENT);}});
}