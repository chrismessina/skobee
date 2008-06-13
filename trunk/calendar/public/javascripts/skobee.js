//MES- Figure out what browser they're using
var ua = navigator.userAgent.toLowerCase();
var IsIE = (-1 != ua.indexOf('msie'));
var IsSaf = (-1 != ua.indexOf('safari'));
var IsFF = !IsIE && !IsSaf && (-1 != ua.indexOf('mozilla'));

/*** Common Display Helpers ***/
function clearDefaultTxt(id,txt) {
  if(txt == $(id).value) {
    $(id).value = "";
  }
}
//html for loading message
var strLoading = '<h5 id="loading-spinner" class=\"loader\">Loading...</h5>';
var strSaving = '<h5 id="loading-spinner" class=\"loader\">Saving...</h5>';
var strSpinner = '<h5 id="loading-spinner" class=\"loader\"></h5>';

function loading(id){
  $(id).innerHTML = strLoading;
}

function destroySpinner(){
  Element.remove('loading-spinner');
}

//MGS TODO we could make this a master-inserter
function loading_insert_top(id, notext){
  if (notext == true) {
    new Insertion.Top(id,strSpinner);
  } else {
    new Insertion.Top(id,strLoading);
  }
}

function validateAJAXResponse(res){
  //MGS- check for 5xx and 4xx response codes and handle appropriately
  // All 590 (AJAX_HTTP_ERROR_STATUS) response codes and 500 errors should
  // be handled before here in the onFailure: or special 590 handlers.
  // handle 5xx errors here, just in case...

  //MGS- adding try/catch to make sure this doesn't cause any more problems
  //than it's trying to solve
  try{
    //MGS- only check the first digits of the HTTP response code
    // to handle the general error classes: 5xx and 4xx
    var errType = res.status.toString().slice(0,1);
    //MGS- returning a full page, if this chars begin the response
    // most likely we are being redirected to the login page because
    // the session expired
    var fullPage = new RegExp(/^<!DOCTYPE html PUBLIC/);
    if ((5 == errType) || (4 == errType)){
      stringIntoFlash("There was a general error.  Please refresh the page.");
      return false;
    } else if(null != res.responseText.match(fullPage)) {
      //MGS- redirect back to the login page, with a param on the
      // querystring that tells us the 'parent' page we were on.
      // If we are editing the people clipboard, we'd redirect back to the
      // main url schedule_details...not the add_clipboard_ajax action
      window.location.href = '/users/login?redirect=' + encodeURIComponent(window.location.href);
      return false;
    }
  } catch (e) {}
  return true;
}

//MGS- overload of Prototype's update content function
//we want to be able to call validateAJAXResponse before
//the insertion is made.  A custom insertion function is possible,
//but a response object isn't passed to it, just the responseText
//Needs to be updated when we update prototype.
Ajax.Updater.prototype.updateContent = function() {
    var receiver = this.responseIsSuccess() ?
      this.containers.success : this.containers.failure;
    var response = this.transport.responseText;

    if (!this.options.evalScripts)
      response = response.stripScripts();

    if (receiver) {
      //MGS- always validate the response before the insertion.
      if (!validateAJAXResponse(this.transport)) {
        return false;
      }
      //MGS- end customization
      if (this.options.insertion) {
        new this.options.insertion(receiver, response);
      } else {
        Element.update(receiver, response);
      }
    }

    if (this.responseIsSuccess()) {
      if (this.onComplete)
        setTimeout(this.onComplete.bind(this), 10);
    }
};

//MES- Used when an AJAX client receives an HTTP error and wishes to display the
//  HTML body (error message) to the user in the Rails flash.
function errIntoFlash(req) {
  stringIntoFlash(req.responseText);
}

function stringIntoFlash(str) {
  clearFlash();
  new Insertion.Top('content','<div id="flash-error-container" class="flash"><div id="flash-error">'+str+'</div></div>');
}

function clearFlash() {
  try {
    var flashes = $A(document.getElementsByClassName('flash', 'content'));
    flashes.each(function(flash){Element.remove(flash)});
  } catch (e){}
}

function yft(id){
  //MGS increasing the duration of to two seconds from a default of one
  new Effect.Highlight(id, {duration:2.0});
}

var AJAX_HTTP_ERROR_STATUS = 590;
var HTTP_STATUS_OK = 200;

function handleFail(){
  //MGS- general handler for 500 errors
  stringIntoFlash('There was a general error.  Please refresh the page.');
  destroySpinner();
  processingClip = false;
}

//MGS- helper function to draw a google map
function drawGoogleMap(lat,lng,div) {
  var map = new GMap($(div));
  map.addControl(new GSmallMapControl());
  var pt = new GPoint(lng,lat);
  map.centerAndZoom(pt, 3);
  var marker = new GMarker(pt);
  map.addOverlay(marker);
  return;
}

function commentCallback(request) {
  Element.hide('comment-add');
  $('comment_tb').value='';
  return;
}

function editComment(id) {
  Element.show('commentedit'+id);
  expandTextArea($('comment_edit_tb'+id));
  return false;
}

function cancelEditComment(id) {
  Element.hide('commentedit'+id);
  return true;
}

function changeCallback(r) {
  Element.hide('change-add');
  $('change_tb').value='';
  return;
}

function editChange(id) {
  Element.show('changeedit'+id);
  expandTextArea($('change_edit_tb'+id));
  return false;
}

function cancelEditChange(id) {
  Element.show('comment_body'+id,'comment_footer'+id);
  Element.hide('changeedit'+id);
  return true;
}

function commentFeedback(inapp_id,parent_id,obj_name,url){
  clearFlash();
  postData = "inapp_id="+inapp_id+"&"+obj_name+"="+parent_id+"&request_url="+url;
  new Ajax.Request('/feedbacks/comment_inappropriate_ajax', {asynchronous:true,postBody:postData,
        onFailure:handleFail,
        onComplete:function(request){if(!validateAJAXResponse(request)){return false;}else{stringIntoFlash("Thank you for bringing this to our attention. We'll look into it immediately.");}}});
  return false;
}

// Skobee autocompleter. Only differences between this and Autocompleter.Local is
// that this one ignores '(' when making partial matches and that the last arg
// (separator_string) is inserted into the element after any successful autocomplete
Autocompleter.Skobee = Class.create();
Autocompleter.Skobee.prototype = Object.extend(new Autocompleter.Base(), {
  initialize: function(element, update, array, options, separator_string) {
    this.baseInitialize(element, update, options);
    this.options.array = array;
    this.options.separator_string = separator_string;
  },

  getUpdatedChoices: function() {
    this.updateChoices(this.options.selector(this));
  },

  updateElement: function(selectedElement) {
    if (this.options.updateElement) {
      this.options.updateElement(selectedElement);
      return;
    }

    var value = Element.collectTextNodesIgnoreClass(selectedElement, 'informal');
    var lastTokenPos = this.findLastToken();
    if (lastTokenPos != -1) {
      var newValue = this.element.value.substr(0, lastTokenPos + 1);
      var whitespace = this.element.value.substr(lastTokenPos + 1).match(/^\s+/);
      if (whitespace)
        newValue += whitespace[0];
      this.element.value = newValue + value + this.options.separator_string;
    } else {
      this.element.value = value + this.options.separator_string;
    }
    this.element.focus();

    //KS- browser-specific code. only do this for safari!
    var agt=navigator.userAgent.toLowerCase();
    if (agt.indexOf("safari") != -1) {
        this.element.setSelectionRange(this.element.value.length, this.element.value.length);
    }

    if (this.options.afterUpdateElement)
      this.options.afterUpdateElement(this.element, selectedElement);
  },

  setOptions: function(options) {
    this.options = Object.extend({
      choices: 10,
      partialSearch: true,
      partialChars: 2,
      ignoreCase: true,
      fullSearch: false,
      frequency: 0.4,
      selector: function(instance) {
        var ret       = []; // Beginning matches
        var partial   = []; // Inside matches
        var entry     = instance.getToken();
        var count     = 0;

        for (var i = 0; i < instance.options.array.length &&
          ret.length < instance.options.choices ; i++) {

          var elem = instance.options.array[i];
          var foundPos = instance.options.ignoreCase ?
            elem.toLowerCase().indexOf(entry.toLowerCase()) :
            elem.indexOf(entry);

          while (foundPos != -1) {
            if (foundPos == 0 && elem.length != entry.length) {
              ret.push("<li><strong>" + elem.substr(0, entry.length) + "</strong>" +
                elem.substr(entry.length) + "</li>");
              break;
            } else if (entry.length >= instance.options.partialChars &&
              instance.options.partialSearch && foundPos != -1) {
              if (instance.options.fullSearch || /\s|\(/.test(elem.substr(foundPos-1,1))) {
                partial.push("<li>" + elem.substr(0, foundPos) + "<strong>" +
                  elem.substr(foundPos, entry.length) + "</strong>" + elem.substr(
                  foundPos + entry.length) + "</li>");
                break;
              }
            }

            foundPos = instance.options.ignoreCase ?
              elem.toLowerCase().indexOf(entry.toLowerCase(), foundPos + 1) :
              elem.indexOf(entry, foundPos + 1);

          }
        }
        if (partial.length)
          ret = ret.concat(partial.slice(0, instance.options.choices - ret.length))
        return "<ul>" + ret.join('') + "</ul>";
      }
    }, options || {});
  }
});

function getDirections() {
  if ($F('location')==''){
    alert('You must enter a start location to get directions.');
    return false;
  }
  document.forms['directions_form'].submit();
}

function showDirections() {
  Element.show('direction_twizzle');
}

function getNextSibling(start) {
  end = start.nextSibling;
  if (end.nodeType == 1) {
     return end;
  } else {
    return end.nextSibling;
  }
}

function getPreviousSibling(start) {
  end = start.previousSibling;
  if (end.nodeType == 1) {
     return end;
  } else {
    return end.previousSibling;
  }
}


//
//HOVERS
//

//MGS- row hover types
var HOVER_TYPE_PLAN = 1;
var HOVER_TYPE_PROPERTY = 2;
var HOVER_TYPE_COMMENT = 3;
var editor_open = false;

function rowHover(el, event, type) {
  if (!editor_open) {
    var hover;
    if ('boolean' == typeof(event)) {
      hover = event;
    } else {
      hover = ('mouseover' == event.type) ? true : false;
    }
    var hover_bar = $('hover_bar_' + el);
    if (hover) {
      //MGS- workaround for hover not working after a YFT
      Element.setStyle(el, {backgroundImage: ''});
      Element.addClassName(el,'hover');
      hover_bar.style.height = 'auto';
      hover_bar.style.width = "15px";
      hover_bar.style.height = $(el).offsetHeight + "px";
    } else {
      Element.removeClassName(el,'hover');
      hover_bar.style.width = "0px";
      hover_bar.style.height = "0px";
    }

    if (HOVER_TYPE_PROPERTY == type) {
      (hover) ? Element.show('change-' + el) : Element.hide('change-' + el);
    } else if (HOVER_TYPE_COMMENT == type) {
      (hover) ? Element.addClassName('add-comment','edit_discuss_red') : Element.removeClassName('add-comment','edit_discuss_red');
    }
  }
}

function clearHover(){
  var e = document.getElementsByClassName('hover', 'content');
  for (var i=0;i<e.length;i++){
    Element.hide('change-' + e[i].id);
    Element.removeClassName(e[i],'hover');
    $('hover_bar_' + e[i].id).style.width = "0px";
    $('hover_bar_' + e[i].id).style.height = "0px";
  }
}

function hoverSplash(el, event) {
  var hover = ('mouseover' == event.type) ? true : false;
    (hover) ? (Element.addClassName(el, 'hover')) : (Element.removeClassName(el,'hover'));
}

function dlHover(el, event, type) {
  var hover = ('mouseover' == event.type) ? true : false;
  (hover) ? Element.addClassName(el,'hover') : Element.removeClassName(el,'hover');
  if (el.nodeName == "DT") {
    try {
    (hover) ? getNextSibling(el).className = 'hover' : getNextSibling(el).className = '';
    (hover) ? Element.addClassName($(el).getElementsByTagName("SPAN")[0], 'hover') : Element.removeClassName($(el).getElementsByTagName("SPAN")[0], 'hover');
    } catch(e){}
  } else {
    (hover) ? getPreviousSibling(el).className = 'hover' : getPreviousSibling(el).className = '';
    (hover) ? Element.addClassName(getPreviousSibling(el).getElementsByTagName("SPAN")[0], 'hover') : Element.removeClassName(getPreviousSibling(el).getElementsByTagName("SPAN")[0], 'hover');
  }
}

function dlHoverBlue(el, event) {
  var hover = ('mouseover' == event.type) ? true : false;
  (hover) ? Element.addClassName(el,'hover_blue') : Element.removeClassName(el,'hover_blue');
}

//MGS- used for js redirects to the login page; helpful for conditional logins...
function redirect_to_login(){
  window.location.href = '/users/login';
}

//MES- Call this function to expand a text area vertically to contain the text
//  within it.  Pass in the text area.
function expandTextArea(ctl)
{
  //MES- Is there a control?
  if( !ctl)
    return;
  
  var lines = ctl.value.split("\n");      //MES- Split the text into lines
  var targetheight = IsFF ? 0 : 1;  //MES- For non-Firefox, add a line
  var numcols=ctl.cols;

  //MES- Iterate through the lines, figuring out if any of them would wrap when displayed
  for(var lineindex=0; lineindex < lines.length; lineindex++)
  {
    //MES- Is this line too long to be displayed
    if(lines[lineindex].length < numcols)
    {
      targetheight += 1;
    }
    else
    {
      //MES- The line is "too long", what style of wrapping would we expect?
      var WrapChunkFctn = getWrapChunkIE;
      if (IsFF)
      {
        WrapChunkFctn = getWrapChunkFF;
      }
      
      //MES- Count the number of displayed lines in this line- the number of lines that the browser will show
      var txt = lines[lineindex];
      while (0 < txt.length)
      {
        //MES- Get the first chunk the browser would show
        var chunk = WrapChunkFctn(txt, numcols);
        if (chunk)
        {
          //MES- Trim off that section, and count the line
          txt = txt.slice(chunk.length + 1);
          targetheight += 1;
        }
        else
        {
          //MES- We're done
          txt = '';
        }
      }
    }
  }
  
  //MES- Do we need to expand the control?
  if (targetheight > ctl.rows)
  {
    ctl.rows = targetheight;
  }
}

function getWrapChunkFF(txt, wraplen)
{
  //MES- If it doesn't need wrapping, just return it
  if (!txt || txt.length <= wraplen)
  {
    return txt;
  }
  
  //MES- If the first section has a delimiter that lets us wrap, we want the location of the last delimiter
  var wraploc = txt.lastIndexOf(' ', wraplen);
  if (-1 != wraploc)
  {
    //MES- There's a place to wrap, return the subset
    return txt.slice(0, wraploc);
  }
  else
  {
    //MES- There's no place to wrap in the first section, so take the NEXT place.
    //NOTE: Firefox does NOT wrap text that's longer than the textbox, it puts in a horizontal scrollbar
    wraploc = txt.indexOf(' ', wraplen);

    //MES- Did we get it?
    if (-1 != wraploc)
    {
      return txt.slice(0, wraploc);
    }
    else
    {
      //MES- Can't wrap, return the whole thing
      return txt;
    }
  }
}

function getWrapChunkIE(txt, wraplen)
{
  //MES- If it doesn't need wrapping, just return it
  if (!txt || txt.length <= wraplen)
  {
    return txt;
  }
  
  //MES- If the first section has a delimiter that lets us wrap, we want the location of the last delimiter
  var wraploc = txt.lastIndexOf(' ', wraplen);
  if (-1 != wraploc)
  {
    //MES- There's a place to wrap, return the subset
    return txt.slice(0, wraploc);
  }
  else
  {
    //MES- There's no place to wrap in the first section, so chop off at the length
    //NOTE: IE wraps in the middle of words (unlike Firefox)
    return txt.slice(0, wraplen);
  }
}