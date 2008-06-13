/**** People Clipboard ****/
var processingClip = false;
function check_contact(cid){
  if(processingClip){return;}
  clearFlash();
  var status = (Element.hasClassName('clipboard_contact_'+cid,'show_hide_checked')) ? false : true;
  if (true == status) {
    Element.addClassName('clipboard_contact_'+cid, 'show_hide_checked');
    Element.removeClassName('clipboard_contact_'+cid, 'show_hide');
  } else {
    Element.addClassName('clipboard_contact_'+cid, 'show_hide');
    Element.removeClassName('clipboard_contact_'+cid, 'show_hide_checked');
  }
  processingClip = true;
  oClipboardUsers['user'+cid].checked = status;
  updateUserHeading();
  //MGS persist changes to the checkbox
  new Ajax.Request('/planners/edit_clipboard_status_ajax?contact_id='+cid+'&status='+status,
                {asynchronous:true, evalScripts:true,
                onFailure:handleFail,
                onLoading:function(request){loading_insert_top('page-title-container', true);},
                onComplete:function(request){complete_check_contact(request);}});
}

function complete_check_contact(request){
  processingClip = false;
  //MGS- check to see if the server returned an ajax error
  if (AJAX_HTTP_ERROR_STATUS == request.status) {
    errIntoFlash(request);
    destroySpinner();
    return;
  }
  if (!validateAJAXResponse(request)) {return;}
  $('content').innerHTML = request.responseText;
  destroySpinner();
}

function remove_from_clipboard(cid,search_string) {
  if(processingClip){return;}
  clearFlash();
  var refresh = Element.hasClassName('clipboard_contact_'+cid,'show_hide_checked') ? true : false;
  //MGS- remove this contact's elements
  new Effect.Fade('contact_row_'+cid, {duration:0.5,afterFinish:function(effect){Element.remove(effect.element);updateClipboard();}});
  //remove from the global object
  delete oClipboardUsers['user'+cid];
  //add the user that was just removed back to the autocomplete array
  clipboard_search_array.push(search_string);

  //MGS TODO -read spinners
  //if (refresh){ loading_insert_top('page-title-container', true); }
  processingClip = true;
  new Ajax.Request('/planners/remove_contact_from_clipboard_ajax?contact_id='+cid+'&refresh='+refresh,
      {asynchronous:true, evalScripts:true,
      onFailure:handleFail,
      onComplete:function(request){complete_remove_from_clipboard(request,refresh,cid);}});
}

function complete_remove_from_clipboard(req,refresh,contact_id) {
  processingClip = false;
  //MGS- check to see if the server returned an ajax error
  if (AJAX_HTTP_ERROR_STATUS == req.status) {
    errIntoFlash(req);
    destroySpinner();
    return;
  }
  if (!validateAJAXResponse(req)) {return;}
  if (refresh){
    $('content').innerHTML = req.responseText;
    updateUserHeading();
  }
  destroySpinner();
}

function updateClipboard() {
  var aNodeList;
  aNodeList = document.getElementsByClassName('contacts-table-row', $('contacts-list'))
  if (0 < aNodeList.length) {
    Element.hide('empty_clip');
  } else {
    Element.show('empty_clip');
  }

  if (aNodeList.length >= CONTACT_CLIPBOARD_LIMIT) {
    Element.hide('people-search');
    Element.show('people-search-limit');
  } else {
    Element.show('people-search');
    Element.hide('people-search-limit');
  }
}

function add_to_clipboard(user_name) {
  if(processingClip){return;}
  clearFlash();
  //refresh the clipboard list and clear out the search box of the just entered user on complete
  processingClip = true;
  new Ajax.Request('/planners/add_contact_to_clipboard_ajax?contact_id='+encodeURIComponent($F('contacts_list')),
                  {asynchronous:true, evalScripts:true, onFailure:handleFail,
                  onComplete:function(request){complete_add_to_clipboard(request);}});
  $('contacts_list').value = '';
  //MGS- now that this user has been added to the people clipboard, remove them from the autocomplete array
  for (var i=0;i<clipboard_search_array.length;i++){
    if (clipboard_search_array[i] == user_name) {
      //remove this contact out of the autocomplete array
      clipboard_search_array.splice(i,1);
    }
  }
}

function complete_add_to_clipboard(request){
  processingClip = false;
  //MGS- check to see if the server returned an ajax error
  if (AJAX_HTTP_ERROR_STATUS == request.status) {
    errIntoFlash(request);
    destroySpinner();
    return;
  }
  if (!validateAJAXResponse(request)) {return;}
  //MGS- since evalScripts() isn't supported for Ajax.Request's, eval the scripts here manually
  request.responseText.evalScripts();
  new Insertion.Top ('contacts-list', request.responseText);
  updateClipboard();
}

function updateUserHeading(){
  //MGS - only display up to two other friends
  var count = 0;
  var maxedOut = false;
  var lastUser = "";
  var header = "";
  var headerUsers = new Array();
  headerUsers[0] = "you";
  //MGS- loop through the associative array
  for (user in oClipboardUsers) {
    if (oClipboardUsers[user].checked) {
      //MGS- exit out of this loop if we reach the max # of friends; HEADER_USERNAME_LIMIT is a global
      if (HEADER_USERNAME_LIMIT == count) {
        maxedOut = true;
        break;
      }
      count++;
      headerUsers[count] = oClipboardUsers[user].login;
    }
  }
  if (0 == count) {
    $('user_heading').innerHTML = "What you're up to...";
  } else if(maxedOut){
    $('user_heading').innerHTML = "What you and your friends are up to...";
  } else {
    //MGS do some stuff to end the list with an 'and'
    lastUser = headerUsers.pop();
    header = headerUsers.join(", ") + " and " + lastUser;
    $('user_heading').innerHTML = "What " + header.escapeHTML() + " are up to...";
  }
}

//global user store for clipboard
var oClipboardUsers = new Object();
//UserDescriptor object definition
function UserDescriptor(login, id, ckd, vis) {
  this.login = login;
  this.id = id;
  this.checked = ckd;
  this.visibility_level = vis;
}


/*** Hovers ***/
function contactHover(el, event) {
  var hover = ('mouseover' == event.type) ? true : false;
  var childCells = $(el).getElementsByTagName("TD");
  for (var i = 0; i < childCells.length; i++) {
    (hover) ? (Element.addClassName(childCells[i], 'hover')) : (Element.removeClassName(childCells[i],'hover'));
  }
}

function tentativeHover(el, event) {
  var hover = ('mouseover' == event.type) ? true : false;
  (hover == false) ? (el.className = el.className.replace('_hover', '')) : (el.className = el.className + '_hover');
}
