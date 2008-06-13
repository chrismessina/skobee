//these styles work for li>div-based clickable elements
function genericHover(el, hover, color) {
  if (color == null) {
    color = '';
  }
  if (hover) {
    $(el).className += " hover" + color;
    $(el).getElementsByTagName("DIV")[0].className += " hover" + color;
  } else {

    if ($(el).className.charAt(' hover') != null) { $(el).className = $(el).className.replace(' hover' + color, '');}
    if ($(el).getElementsByTagName("DIV")[0].className.charAt('hover') != null) {$(el).getElementsByTagName("DIV")[0].className = $(el).getElementsByTagName("DIV")[0].className.replace('hover' + color, '');}

    if ($(el).className.charAt('hover') != null) { $(el).className = $(el).className.replace('hover' + color, '');}
    if ($(el).getElementsByTagName("DIV")[0].className.charAt('hover') != null) { $(el).getElementsByTagName("DIV")[0].className = $(el).getElementsByTagName("DIV")[0].className.replace('hover' + color, '');}
  }
}

function statusHover(el, event) {
  //MGS- if a bubble editor is open, don't change the highlight
  if (bubble_open) { return; }
  var hover = ('mouseover' == event.type) ? true : false;
  (hover) ? Element.addClassName(el,'hover_status') : Element.removeClassName(el,'hover_status');
}

function switchPlace(el0, el1, el2, el3, el4, el5, el6, el6value) {
  //KS- clear the flash in case there was an error message left there from
  //finding by address
  clearFlash();

  Element.show(el1);
  Element.hide(el2);
  Element.hide(el3);
  el0.parentNode.className = "tab_selected";
  $(el4).className = "tab_unselected";
  $(el5).className = "tab_unselected";
  $(el6).value = el6value;
}

/*** Plan Details ***/
var SearchByAddressPlaceResults = Class.create();
SearchByAddressPlaceResults.prototype = {
    initialize: function(template, require_address, private_venues_ok, search_by_address_name,
                         search_by_address_location, search_by_address_distance, place_results,
                         search_button, place_id, entries_per_page, search_panel_name, result_panel_name,
                         result_prefix, result_value_suffix, pager_prefix, no_results_div_name, paging_div_name) {
      this.template = template;
      this.require_address = require_address;
      this.private_venues_ok = private_venues_ok;
      this.entries_per_page = entries_per_page;

      this.search_by_address_name = search_by_address_name;
      this.search_by_address_location = search_by_address_location;
      this.search_by_address_distance = search_by_address_distance;
      this.place_results = place_results;
      this.search_button = search_button;
      this.place_id = place_id;
      this.search_panel_name = search_panel_name;
      this.result_panel_name = result_panel_name;
      this.result_prefix = result_prefix;
      this.result_value_suffix = result_value_suffix;
      this.pager_prefix = pager_prefix;
      this.no_results_div_name = no_results_div_name;
      this.paging_div_name = paging_div_name

      //KS- set up listener for search button
      Event.observe(this.search_button, 'click', this.searchButtonPressed.bindAsEventListener(this));

      //KS- set up a listener for keypress
      Event.observe(document, "keypress", this.onKeyPress.bindAsEventListener(this));

      //KS- set up a listener for clicking on the paging div -- we want to give focus back to the search button in this case
      Event.observe(document, "click", this.pagingDivOnClick.bindAsEventListener(this));

      //KS- set the initial index to 0
      this.index = 0;

      //KS- set it as inactive initially (set to active when search button is pressed)
      this.active = false;

      //KS- start it out on the first page
      this.page = 1;
    },

    //KS- copied verbatim from the script.aculo.us autocompleter to handle some IE-specific stuff
    show: function() {
        if(!this.iefix &&
            (navigator.appVersion.indexOf('MSIE')>0) &&
            (navigator.userAgent.indexOf('Opera')<0) &&
            (Element.getStyle($(this.template), 'position')=='absolute')) {
                new Insertion.After($(this.template),
                    '<iframe id="' + $(this.template).id + '_iefix" '+
                    'style="display:none;position:absolute;filter:progid:DXImageTransform.Microsoft.Alpha(opacity=0);" ' +
                    'src="javascript:false;" frameborder="0" scrolling="no"></iframe>');
                this.iefix = $($(this.template).id+'_iefix');
        }
        if(this.iefix) setTimeout(this.fixIEOverlapping.bind(this), 50);
    },

    //KS- copied verbatim from the script.aculo.us autocompleter to handle some IE-specific stuff
    fixIEOverlapping: function() {
        Position.clone($(this.template), this.iefix);
        this.iefix.style.zIndex = 1;
        $(this.template).style.zIndex = 2;
        Element.show(this.iefix);
    },

    //KS- bound to the search button
    searchButtonPressed: function() {
        //KS- grab the values from the form fields
        this.fulltext = this.search_by_address_name.value;
        this.location = this.search_by_address_location.value;
        this.distance = this.search_by_address_distance.value;

        //KS- give the search button focus in case it doesn't already have it
        //(this happens when pressing ENTER)
        this.search_button.focus();

        //KS- clear the flash in case there was an error message from the
        //find by address ajax
        clearFlash();

        this.reloadResults(1);
    },

    onKeyPress: function(event) {
        if (this.active) {
            switch(event.keyCode) {
        case Event.KEY_ESC:
            this.hide();
            this.active = false;
            Event.stop(event);
            return;
        case Event.KEY_UP:
            this.markPrevious();
            Event.stop(event);
            return;
        case Event.KEY_DOWN:
            this.markNext();
            Event.stop(event);
            return;
        case Event.KEY_TAB:
        case Event.KEY_RETURN:
            this.selectEntry();
            Event.stop(event);
            return;
            }
        }

//KS- commented out until i can figure out a way to figure out the max # of pages
//        if(this.active)
//            switch(event.keyCode) {
//                case Event.KEY_LEFT:
//                    if (this.page > 1) {
//                        this.reloadResults(this.page - 1);
//                    }
//                    return;
//               case Event.KEY_RIGHT:
//                    this.reloadResults(this.page + 1);
//                    return;
//        }
    },

    selectEntry: function() {
        //KS- trim the string so it fits in the display
        $('search_by_address_result_text').innerHTML = $(this.result_prefix + this.index).innerHTML.substring(0, 35) + "...";

        //KS- get the hidden form field element that leads us to the value of the place id
        el = $(this.result_prefix + this.index + this.result_value_suffix);
        this.place_id.value = el.value;

        flipSearchDisplay(this.search_panel_name,this.result_panel_name);
    },

    //KS- used to change selection to previous when arrow_up is pressed (should we refactor
    //this to use this.render()?)
    markPrevious: function() {
        if(this.index > 0) {
            Element.removeClassName($(this.result_prefix + this.index),"selected");
            Element.addClassName($(this.result_prefix + (this.index - 1)),"selected");
            this.index--;
        } else {
            this.index = 0;
        }
    },

    //KS- used to change selection to next when arrow_down is pressed (should we refactor
    //this to use this.render()?)
    markNext: function() {
        if(this.index < this.entryCount-1) {
            Element.removeClassName($(this.result_prefix + this.index),"selected");
            Element.addClassName($(this.result_prefix + (this.index + 1)),"selected");
            this.index++;
        } else {
            this.index = this.entryCount - 1;
        }
    },

    reloadResults: function(page) {
        this.page = page;
        this.index = 0;

      postData = "fulltext=" + this.fulltext
        + "&location=" + this.location
        + "&max_distance=" + this.distance
        + "&template=" + this.template
        + "&require_address=" + this.require_address
        + "&private_venues_ok=" + this.private_venues_ok
        + "&result_prefix=" + this.result_prefix
        + "&result_value_suffix=" + this.result_value_suffix
        + "&pager_prefix=" + this.pager_prefix;

      //MGS- if we were passed a page value, postpend it to the string
      if (page) {
        postData = postData + "&page=" + page;
      }

      new Ajax.Updater('venue_results','/plans/search_venues_ajax',
        {asynchronous:true, evalScripts:true, method: 'post', postBody: postData,
        onLoading:function(request){new Insertion.Bottom('venue_results',"<div class='loading' style='padding: 5px 0'><br/>loading...</div>")},
        onComplete:this.venue_results_complete.bind(this)});

      //KS- copied from script.aculo.us autocompleter. i believe it's setting the position of the results div
      //based on the position of the search box.
      if(!this.place_results.style.position || this.place_results.style.position=='absolute') {
          this.place_results.style.position = 'absolute';
          Position.clone($('find_place_by_location_div'), this.place_results, {setHeight: false, offsetTop: $('find_place_by_location_div').offsetHeight});
      }

      //KS- set it to active so that we can do the proper thing in the event handling
      this.active = true;
    },

    venue_results_complete: function(request) {
        //KS- put the error into the flash if there was an error on the server (currently
        //this only happens when the location is not understood)
        if (AJAX_HTTP_ERROR_STATUS == request.status) {
            errIntoFlash(request);
            return;
        }

        Element.addClassName($(this.result_prefix + '0'),"selected");

        resultEntries = document.getElementsByClassName('venue_result');
        this.entryCount = resultEntries.length / 2;

        //KS- add onhover and onclick listeners to each result
        Element.cleanWhitespace($(this.template));
        if($(this.template).firstChild && $(this.template).firstChild.childNodes) {
            Element.cleanWhitespace($(this.template).firstChild);

            if (resultEntries.length > 0) {
              for (var i = 0; i < this.entryCount; i++) {
                    var entry = this.getEntry(i);
                    this.addObservers(entry);
              }
            }
            Element.hide($(this.no_results_div_name));
        }

        //KS- show the no results div if there were no results
        if (this.entryCount == 0) {
            Element.show($(this.no_results_div_name));
        }

        //KS- show the results template
        Element.show($(this.template));

        //KS- set the current pager page display to selected
        $(this.pager_prefix + this.page).parentNode.className = "selected";

        this.give_focus_to_search_button();

        return;
    },

    //KS- use this to add hover and click listeners to the results
    addObservers: function(element) {
        Event.observe(element, "mouseover", this.onHover.bindAsEventListener(this));
        Event.observe(element, "click", this.onClick.bindAsEventListener(this));
    },

    //KS- when a result is hovered over, highlight it
    onHover: function(event) {
        var element = Event.findElement(event, 'LI');
        if(this.index != this.getElementIndex(element))
        {
            this.index = this.getElementIndex(element);
            this.render();
        }
        Event.stop(event);
    },

    //KS- convenience method for getting hold of a result element's index
    getElementIndex: function(element) {
        return element.id.substring(this.result_prefix.length);
    },

    //KS- when a result is clicked on, select it
    onClick: function(event) {
        var element = Event.findElement(event, 'LI');
        this.index = this.getElementIndex(element);
        this.selectEntry();
        this.hide();
    },

    pagingDivOnClick: function(event) {
        //KS- get the event target -- this property varies across browsers
        var target;
        if (event.target) {
            target = event.target;
        } else {
            target = event.srcElement;
        }

        //KS- if the clicked node is an ancestor of the dropdown or if the search button image
        //was the target, stop the event, otherwise hide the dropdown
        if (nodeIsAncestorOf(target, this.template) || target.parentNode.id == this.search_button.id) {
            Event.stop(event);
        } else {
            setTimeout(this.hide.bind(this), 250);
            this.active = false;
        }
    },

    give_focus_to_search_button: function() {
      //KS- this choice of syntax is odd, but i couldn't get it to work properly with bind
      //(if you know how, please let me know)
      search_button_id = this.search_button.id
      setTimeout("document.getElementById('" + search_button_id + "').focus()", 250);
    },

    //KS- use this to do the hiding of the template -- it also
    //needs to hide the iefix if we're in ie (copied from script.aculo.us autocompleter)
    hide: function() {
        Element.hide($(this.template));
        if(this.iefix) Element.hide(this.iefix);
    },

    //KS- convenience function to grab a result entry by index
    getEntry: function(index) {
        return document.getElementsByClassName('venue_result')[index * 2 + 1];
    },

    //KS- go through all the result elements and set the class for the appropriate
    //one to selected
    render: function() {
        if(this.entryCount > 0) {
            for (var i = 0; i < this.entryCount; i++)
                this.index==i ?
                Element.addClassName(this.getEntry(i),"selected") :
                Element.removeClassName(this.getEntry(i),"selected");
        }
    }
};

//KS- return true if node is an ancestor of a node with id "id", false otherwise
function nodeIsAncestorOf(node, id) {
    var parent = node;
    var isAncestor = false;
    while (parent != null) {
        if (parent.id == id) {
            isAncestor = true;
            break;
        }

        parent = parent.parentNode;
    }

    return isAncestor;
}

function setPlaceInWhereControl(place_id, place_origin, place_name) {
    //KS- create the value to display
    $('place_id').value = place_id;
    $('search_by_name_result_text').innerHTML=place_name.substring(0, 35) + "...";

    //KS- set the place origin
    $('place_origin').value = place_origin;

    //KS- hide the contents of the find by address and add by place tabs if they're hidden
    if (Element.visible($('add_place_div'))) { Element.hide($('add_place_div')); }
    if (Element.visible($('find_place_by_location_div'))) { Element.hide($('find_place_by_location_div')); }

    //KS- show the contents of the find by name panel, but hide the search portion
    Element.show($('search_by_name_result_panel'));
    Element.hide($('search_by_name_search_panel'));
    Element.show($('find_place_by_name_div'));

    //KS- select the find by name tab
    $('find_place_by_name_tab').className = "tab_selected";
    $('find_place_by_location_tab').className = "tab_unselected";
    $('add_place_tab').className = "tab_unselected";
}

function flipSearchDisplay(toHide, toShow, focus) {
  if (Element.visible($(toHide))) {
   Element.hide($(toHide));
   Element.show($(toShow));
  }
  else {
   Element.show($(toShow));
   Element.hide($(toHide));
  }
  if (focus) $(focus).focus();
  return;
}

function validatePlaceNameExists() {
  //KS- empty out the flash because we might need to stick stuff in
  clearFlash();
  if ($('place_origin').value == ADD_PLACE_VALUE && $('place_name').value == '') {
    stringIntoFlash('You must enter a name to create a new place.');
    return false;
  } else {
    return true;
  }
}

//MGS- helper for adding users from my regulars into who field
function addToWhoField(field, display_name, login_name, firefox) {
  f = $(field);
  //MGS- TODO, if we wanted to be clever here, we would only add the comma when necessary
  f.value=f.value + display_name + ' (' + login_name + '), ';
  expandTextArea(f, firefox);
}
//MGS- helper for adding users from my regulars into who field
function selectPlace(field, hidden_field, autocomplete_hidden_field, place_name, place_id, place_addr) {
  f = $(field);
  hf = $(hidden_field);
  ahf = $(autocomplete_hidden_field);
  f.value = place_name + " (" + place_addr + ")";
  hf.value = place_id;
  ahf.value = 1;
  //MGS TODO- we should clear the search results here, if there were any
}

function filterComments(filter){
  //MGS- get all comments; class name of comment
  var comments = document.getElementsByClassName('comment','change-list');
  var before_length = comments.length;
  var hidden = 0;
  for (var i=0;i<comments.length;i++){
    if (!Element.hasClassName(comments[i], filter)) {
      Element.hide(comments[i]);
      hidden++;
    }
  }
  if (before_length == hidden){
    try{
      Element.remove('empty_comments');
    } catch (e){}
    if (filter == 'place_change') {
      new Insertion.Bottom('change-list','<div id="empty_comments" class="no_results">No one has made any comments or suggestions about a place for this plan.</div>');
    }else {
      new Insertion.Bottom('change-list','<div id="empty_comments" class="no_results">No one has made any comments or suggestions about a time/date for this plan.</div>');
    }
  }
}

function unfilterComments(){
  var comments = document.getElementsByClassName('comment','change-list');
  for (i=0;i<comments.length;i++){
    Element.show(comments[i]);
  }
  try{
  Element.remove('empty_comments');
  } catch (e){}
}

function initAutocompleter(edit_field, autocomplete_div){
  new Autocompleter.Skobee(edit_field, autocomplete_div, search_array, { tokens: new Array(',','\n'), fullSearch: false, partialSearch: true, partialChars: 1, frequency: 0.001}, ', ');
  return;
}

function displayTimeFields(div_id, index){
  if (index.value == 0) {
    Element.show('time-div', 'date-div');
    if ('date-div' == div_id) {
      document.forms['plan_form'].date_month.value = current_time.getMonth() + 1;
      document.forms['plan_form'].date_day.value = current_time.getDate();
      document.forms['plan_form'].date_year.value = current_time.getFullYear();
    } else if ('time-div' == div_id) {
      document.forms['plan_form'].plan_hour.value = '6';
      document.forms['plan_form'].plan_min.value = '00';
      document.forms['plan_form'].plan_meridian.selectedIndex = 1;
    }
  } else {
    if ('date-div' == div_id) {
      clearSpecificDate();
    }
    else if ('time-div' == div_id) {
      clearSpecificTime();
    }
  }
}

function clearFuzzyTime(){
  $('timeperiod').value = 0;
}

function clearSpecificTime(){
  $('plan_hour').value = "";
  $('plan_min').value = "";
  $('plan_meridian').options[0].selected = "true";
}

function clearSpecificDate(){
  $('hiddendate').value = "";
  $('date_month').value = "";
  $('date_day').value = "";
  $('date_year').value = "";
}

function clearFuzzyDate(){
  $('dateperiod').value = 0;
}

function validateDates(){
  //timeperiod not selected, so make sure times are all filled in and proper
  if ($F('timeperiod') == 0){
    if ((!$F('plan_hour').match(new RegExp(/(^[1-9]$)|(^[0][1-9]$)|(^[1][012]$)/))) ||
       (!$F('plan_min').match(new RegExp(/(^[0-5][0-9]$)/))) ||
       (0 == $F('plan_meridian'))) {
      stringIntoFlash("The time set is invalid!");
      return false;
    }
  }
  if ($F('dateperiod') == 0){
    if ((!$F('date_year').match(new RegExp(/(^(19|20)\d\d$)/))) || (!$F('date_month').match(new RegExp(/(^[1-9]$)|(^[0][1-9]$)|(^[1][012]$)/))) ||
    (!$F('date_day').match(new RegExp(/(^[1-9]$)|(^[0][1-9]$)|(^[12][0-9]$)|(^[3][01]$)/)))) {
      stringIntoFlash("The date set is invalid.");
      return false;
    }
    //MGS- check that the date is today or in the future;
    // we could always add time checking as well, but that seems a little intrusive.
    //MGS- we are setting a global javascript variable that contains the current time
    // This allows us to use the user's timezone setting and allows us to still validate
    // the time correctly even when the user's PC clock is off.
    // The javascript month is an integer 0-11.
    if (null != current_time){
      var plan_time = new Date($F('date_year'),($F('date_month')-1),$F('date_day'));
      if (plan_time < current_time) {
        stringIntoFlash("Unable to create plans in the past.");
        return false;
      }
    }
  }

  return true;
}


/*** Edit Functions for Plan Details ***/
function openWhat(){
  Element.show('plan_what_editor');
  expandTextArea($('plan_description'));
  editor_open=true;
}

function cancelWhat(){
  Element.hide('plan_what_editor');
  editor_open=false;
  clearHover('plan_what_row');
  clearFlash();
}

function saveWhat(){
  $('plan_form').action='/plans/edit_what';
  $('plan_form').submit();
}

function openWhen(){
  Element.show('plan_when_editor');
  editor_open=true;

  filterComments('time_change');
  editor_open=true;
}

function cancelWhen(){
  Element.hide('plan_when_editor');

  unfilterComments();
  editor_open=false;
  clearHover('plan_when_row');
  clearFlash();
}

function saveWhen(){
  if(!validateDates()){
    return false;
  }
  $('plan_form').action='/plans/edit_when';
  $('plan_form').submit();
  return true;
}

function openWho(){
  Element.show('plan_who_editor');
  hideSidebars();
  Element.show('sidebar_users_stub');
  populateUsersIfNeeded();
  new Autocompleter.Skobee('plan_who','plan_who_div', search_array, { tokens: new Array(',','\n'), fullSearch: false, partialSearch: true, partialChars: 1, frequency: 0.001}, ', ');
  editor_open=true;
}

function cancelWho(){
  Element.hide('plan_who_editor');
  showSidebars();
  Element.hide('sidebar_users_stub');

  //MGS-clear the remove row, if it exists
  try{
    Element.remove('remove_who_div');
  } catch (e){}
  Field.clear('plan_who');

  editor_open=false;
  clearHover('plan_who_row');
  clearFlash();
}

function saveWho(){
  $('plan_form').action='/plans/edit_who';
  $('plan_form').submit();
}

//MES- Hide all of the sidebar controls
function hideSidebars()
{
  applyToSidebarDivs(Element.hide);
}

//MES- Show all the sidebar controls (reverses hideSidebars)
function showSidebars()
{
  applyToSidebarDivs(Element.show);
}

//MES- Find all the sidebar controls (divs), and apply the func to them
function applyToSidebarDivs(func)
{
  var res = new Array();
  var sbParent = $('sidebar');
  //MES- Walk the children, hiding each
  var children = sbParent.getElementsByTagName('div');
  for (var i=0; i < children.length; ++i)
  {
    //MES- Is this one we care about?
    var child = children[i];
    var childName = child.getAttribute('id');
    if (childName && 0 == childName.indexOf('sidebar_'))
    {
      func(child);
    }
  }

  return res;
}

function populateUsersIfNeeded()
{
  showUrlInfo('sidebar_users_stub', null, '/plans/sidebar_touchlist?show_less=false');
}

function openWhere(){
  Element.show('plan_where_editor');
  editor_open=true;
  filterComments('place_change');
  flipSearchDisplay('search_by_name_result_panel', 'search_by_name_search_panel', 'place_search');
  result_handler = new SearchByAddressPlaceResults('venue_results', 1, 1, $('place_search_by_address_name'), $('place_search_by_address_location'), $('max_distance'), $('venue_results'), $('search_by_address_button'), $('place_id'), 8, 'search_by_address_search_panel','search_by_address_result_panel','item_', '_value', 'pager_','no_results','paging_div');

}

function cancelWhere(){
  Element.hide('plan_where_editor');

  unfilterComments();
  editor_open=false;
  clearHover('plan_where_row');
  clearFlash();
}

function saveWhere(){
   //KS- if text has been typed but we haven't selected a place, display an error
   if (whereFieldHasBogusPlace()) {
      stringIntoFlash("We were unable to find the place you entered. If you'd like to add this place, simply select the 'add a place' tab.");
      return false;
   }

  $('plan_form').action='/plans/edit_where';
  $('plan_form').submit();
}

function closeAllEdits(){
  Element.hide('plan_what_editor','plan_when_editor','plan_where_editor','plan_who_editor','change-add');
  clearHover();
}

function changePrivacy(){
  $('plan_form').action='/plans/change_privacy';
  $('plan_form').submit();
  return true;
}

function changeLock(){
  $('plan_form').action='/plans/change_lock';
  $('plan_form').submit();
  return true;
}

function cancelPlan(cancel){
  if (cancel)
  $('plan_form').action='/plans/cancel';
  else
  $('plan_form').action='/plans/uncancel';

  $('plan_form').submit();
  return true;
}

function addComment(){
  if (editor_open)
    return;
  Element.show('change-add');
  editor_open=true;
}

function cancelComment(){
  editor_open = false;
  Element.hide($('change-add'));
  $('change_tb').value='';
  rowHover('plan_discuss_row', false, HOVER_TYPE_COMMENT);
  return false;
}

//KS- constants that mirror the constants in the PlansController. these
//are used to indicate the different components of the where control
var FIND_BY_NAME = 0;
var FIND_BY_ADDRESS = 1;
var ADD_NEW_PLACE = 2;

//KS- this class controls the tabs and display area of the where control
//it assumes the layout is as follows:
//<element>
//  <place origin hidden field/>
//  <place id hidden field/>
//  <tabs container>
//      <find by name tab/>
//      <find by address tab/>
//      <add a place tab/>
//  </tabs container>
//  <find by name div>
//      <panel div>
//          <name field/>
//          <other junk.../>
//      </panel div>
//  </find by name div>
//  <find by address div>
//      <panel div>
//          <title/>
//          <name field/>
//          <other junk.../>
//      </panel div>
//  </find by address div>
//  <add a place div>
//      <dl for form fields>
//          <name dt/>
//          <dd>
//              <place name input/>
//          </dd>
//          <address dt/>
//          <address dd/>
//          <phone dt/>
//          <phone dd/>
//          <url dt/>
//          <url dd/>
//      </dl for form fields>
//      <table for checkbox>
//          <tr>
//              <td>
//                  <make public checkbox/>
//              </td>
//              <other junk.../>
//          </tr>
//      </table for checkbox>
//  </add a place div>
//  <instructions for find by name header/>
//  <other junk.../>
//</element>
var WhereControl = Class.create();
WhereControl.prototype = {
    initialize: function(element, active_component, makePublicCheckboxChecked) {
        this.element = $(element);

        //KS- instance variables for the hidden input fields for place_origin and place_id
        this.place_origin = $('place_origin');
        this.place_id = $('place_id');

        //KS- instance variable for instructions for find by name tab
        this.find_by_name_instructions = $('find_by_name_instructions');

        //KS- instance variables for the various name fields
        this.find_by_name_name_field = $('place_search');
        this.find_by_address_name_field = $('place_search_by_address_name');
        this.add_new_place_name_field = $('place_name');

        //KS- instance variables for the tabs and divs
        this.find_by_name_tab = $('find_place_by_name_tab');
        this.find_by_address_tab = $('find_place_by_location_tab');
        this.add_place_tab = $('add_place_tab');
        this.find_by_name_div = $('find_place_by_name_div');
        this.find_by_address_div = $('find_place_by_location_div');
        this.add_place_div = $('add_place_div');

        //KS- instance variable for make this public checkbox in add new place
        this.make_public_checkbox = $('request_public');

        //KS- instance variables for phone and url dts and dds in add new places
        this.phone_dt = $('phone_dt');
        this.phone_dd = $('phone_dd');
        this.url_dt = $('url_dt');
        this.url_dd = $('url_dd');

        //KS- set instance variable for tab container
        this.tab_container = $('tab_container');

        //KS- use this to store the place name across tabs
        this.name = '';

        this.setActiveComponent(active_component);

        //KS- add onclick listeners for each of the tab links
        Event.observe($('find_by_name_link'), "click", this.clickedFindByNameTab.bindAsEventListener(this));
        Event.observe($('find_by_address_link'), "click", this.clickedFindByAddressTab.bindAsEventListener(this));
        Event.observe($('add_place_link'), "click", this.clickedAddNewPlaceTab.bindAsEventListener(this));

        //KS- add change listeners to the name fields so that we can persist the name across tabs
        Event.observe(this.find_by_name_name_field, "change", this.changedNameFieldFindByName.bindAsEventListener(this));
        Event.observe(this.find_by_address_name_field, "change", this.changedNameFieldFindByAddress.bindAsEventListener(this));
        Event.observe(this.add_new_place_name_field, "change", this.changedNameFieldNewPlace.bindAsEventListener(this));

        //KS- add a select listener for the make public checkbox
        Event.observe(
            this.make_public_checkbox,
            "click",
            this.showExtraAddPlaceFields.bindAsEventListener(this));

        //KS- show the phone and url fields in the add a place div if the checkbox was already
        //checked when we initialize
        if (makePublicCheckboxChecked) {
            this.make_public_checkbox.checked = true;
            this.showExtraAddPlaceFields();
        } else {
            this.make_public_checkbox.checked = false;
            this.hideExtraAddPlaceFields();
        }
    },

    //KS- when the find by name name field changes, store the value into this.place_name
    changedNameFieldFindByName: function() {
        this.name = this.find_by_name_name_field.value;
    },

    //KS- when the find by address name field changes, store the value into this.place_name
    changedNameFieldFindByAddress: function() {
        this.name = this.find_by_address_name_field.value;
    },

    //KS- when the add new place name field changes, store the value into this.place_name
    changedNameFieldNewPlace: function() {
        this.name = this.add_new_place_name_field.value;
    },

    //KS- display the phone and url fields in the add a place div
    showExtraAddPlaceFields: function() {
        Element.show(this.phone_dt);
        Element.show(this.phone_dd);
        Element.show(this.url_dt);
        Element.show(this.url_dd);
    },

    //KS- hide the phone and url fields in the add a place div
    hideExtraAddPlaceFields: function() {
        Element.hide(this.phone_dt);
        Element.hide(this.phone_dd);
        Element.hide(this.url_dt);
        Element.hide(this.url_dd);
    },

    //KS- when the find by name tab is clicked, set find by name to be the active component
    clickedFindByNameTab: function() {
        this.find_by_name_name_field.value = this.name;
        this.setActiveComponent(FIND_BY_NAME);
    },

    //KS- when the find by address tab is clicked, set find by addresss to be the active component
    clickedFindByAddressTab: function() {
        this.find_by_address_name_field.value = this.name;
        this.setActiveComponent(FIND_BY_ADDRESS);
    },

    //KS- when the add a place tab is clicked, set add a place to be the active component
    clickedAddNewPlaceTab: function() {
        this.add_new_place_name_field.value = this.name;
        this.setActiveComponent(ADD_NEW_PLACE);
    },

    //KS- get one of the tabs
    getComponentTab: function(index) {
        switch(index) {
            case FIND_BY_NAME:
                return this.find_by_name_tab;
            case FIND_BY_ADDRESS:
                return this.find_by_address_tab;
            case ADD_NEW_PLACE:
                return this.add_place_tab;
            //KS- this should NEVER happen
            default: return 0;
        }
    },

    //KS- get the component displayed when the tab of the same index
    //is selected
    getComponentDiv: function(index) {
        switch(index) {
            case FIND_BY_NAME:
                return this.find_by_name_div;
            case FIND_BY_ADDRESS:
                return this.find_by_address_div;
            case ADD_NEW_PLACE:
                return this.add_place_div;
            //KS- this should NEVER happen
            default: return 0;
        }
    },

    //KS- activate the tab and div of the given component. this should
    //only be called by setActiveComponent
    activateComponent: function(index) {
        Element.addClassName(this.getComponentTab(index), 'tab_selected');
        Element.removeClassName(this.getComponentTab(index), 'tab_unselected');
        Element.show(this.getComponentDiv(index));
    },

    //KS- deactivate the tab and div of the given component. this should
    //only be called by setActiveComponent
    deactivateComponent: function(index) {
        Element.addClassName(this.getComponentTab(index), 'tab_unselected');
        Element.removeClassName(this.getComponentTab(index), 'tab_selected');
        Element.hide(this.getComponentDiv(index));
    },

    //KS- activate the given component and deactivate all the others
    setActiveComponent: function(component) {
        //KS- set the place origin hidden field to the component we're activating
        this.place_origin.value = component;

        //KS- activate the given component
        this.activateComponent(component);

        switch(component) {
            case FIND_BY_NAME:
                Element.show(this.find_by_name_instructions);
                this.deactivateComponent(FIND_BY_ADDRESS);
                this.deactivateComponent(ADD_NEW_PLACE);
                break;
            case FIND_BY_ADDRESS:
                Element.hide(this.find_by_name_instructions);
                this.deactivateComponent(FIND_BY_NAME);
                this.deactivateComponent(ADD_NEW_PLACE);
                break;
            case ADD_NEW_PLACE:
                Element.hide(this.find_by_name_instructions);
                this.deactivateComponent(FIND_BY_NAME);
                this.deactivateComponent(FIND_BY_ADDRESS);
                break;
            //KS- this should never happen
            default: break;
        }
    }
}


//KS- the index numbers for the various divs inside the overall div
var MY_PLACES_HEADER_DIV_INDEX = 0;
var MY_PLACES_DIV_INDEX = 1;
var SKOBEE_PLACES_HEADER_DIV_INDEX = 2;
var SKOBEE_PLACES_DIV_INDEX = 3;

//KS- the index numbers for the components of the places_array that holds
//the place information for both local and remote autocompleting
var PLACE_IDS_INDEX = 0;
var PLACE_NAMES_INDEX = 1;
var PLACE_LOCATIONS_INDEX = 2;
var PLACE_NORMALIZED_NAMES_INDEX = 3;

var PlaceSearchByNameAutocompleter = Class.create();
PlaceSearchByNameAutocompleter.prototype = {
  initialize: function(element, update, array, url, options) {
    this.element            = $(element);
    this.update             = $(update);
    this.hasFocus           = false;
    this.changed            = false;
    this.active             = false;
    this.index              = 0;
    this.entryCount         = 0;
    this.localEntryCount    = 0;
    this.remoteEntryCount   = 0;

    if (this.setOptions)
      this.setOptions(options);
    else
      this.options = options || {};

    this.options.paramName              = this.options.paramName || this.element.name;
    this.options.tokens                 = this.options.tokens || [];
    this.options.frequency              = this.options.frequency || 0.01;
    this.options.minChars               = this.options.minChars || 1;
    this.options.minServerSearchChars   = this.options.minServerSearchChars || 3;
    this.options.asynchronous           = true;
    this.options.onComplete             = this.onComplete.bind(this);
    this.options.defaultParams          = this.options.parameters || null;
    this.url                            = url;
    this.options.onShow                 = this.options.onShow ||
    function(element, update){
      if(!update.style.position || update.style.position=='absolute') {
        update.style.position = 'absolute';
        Position.clone(element, update, {setHeight: false, offsetTop: element.offsetHeight});
      }
      Effect.Appear(update,{duration:0.15});
    };
    this.options.onHide = this.options.onHide ||
    function(element, update){ new Effect.Fade(update,{duration:0.15}) };

    if (typeof(this.options.tokens) == 'string')
      this.options.tokens = new Array(this.options.tokens);

    this.observer = null;

    this.element.setAttribute('autocomplete','off');

    Element.hide(this.update);

    Event.observe(this.element, "blur", this.onBlur.bindAsEventListener(this));
    Event.observe(this.element, "keypress", this.onKeyPress.bindAsEventListener(this));

    this.options.array = array;
  },

  getUpdatedChoices: function() {
    //KS- update the local search portion of the autocompleter
    this.updateChoices(this.options.selector(this.options.array), 1);

    //KS- if there were no local search results, display a message notifying the user
    if (this.entryCount == 0) {
        Element.cleanWhitespace(this.update);
        Element.cleanWhitespace(this.update.childNodes[MY_PLACES_DIV_INDEX]);
        this.update.childNodes[MY_PLACES_DIV_INDEX].innerHTML = '<ul><li><span class="message">No matches were found in your places.</span></li></ul>';
    }

    //KS- clear the remote results area
    this.update.childNodes[SKOBEE_PLACES_DIV_INDEX].innerHTML = '';

    //KS- get the data to update the skobee's places section of the div
    //if the user has inputted enough characters
    if(this.getToken().length>=this.options.minServerSearchChars) {
        //KS- start the loading indicator, turn it off in onComplete
        this.startIndicator();

      entry = encodeURIComponent(this.options.paramName) + '=' +
        encodeURIComponent(this.getToken());

      this.options.parameters = this.options.callback ?
        this.options.callback(this.element, entry) : entry;

      if(this.options.defaultParams)
        this.options.parameters += '&' + this.options.defaultParams;

      new Ajax.Request(this.url, this.options);
    } else {
        //KS- nothing to show for the skobee search results, so display
        //a message telling the user to enter 3 or more chars
        Element.cleanWhitespace(this.update);
        Element.cleanWhitespace(this.update.childNodes[SKOBEE_PLACES_DIV_INDEX]);
        this.update.childNodes[SKOBEE_PLACES_DIV_INDEX].innerHTML = '<ul><li><span class="message">Enter at least 3 characters to search Skobee.</span></li></ul>';
    }
  },

  onComplete: function(request) {
    //KS- get the javascript array from the json text
    var places_array = JSON.parse(request.responseText)

    //KS- strip out any entries from places_array that are already in this.options.array
    //because they are repeated places
    for (var i = 0; i < places_array[PLACE_IDS_INDEX].length; i++) {
        for (var j = 0; j < this.options.array[PLACE_IDS_INDEX].length; j++) {
            //KS- if there is an entry with the same id, strip it out of places_array
            if (places_array[PLACE_IDS_INDEX][i] == this.options.array[PLACE_IDS_INDEX][j]) {
                places_array[PLACE_IDS_INDEX].splice(i, 1);
                places_array[PLACE_NAMES_INDEX].splice(i, 1);
                places_array[PLACE_LOCATIONS_INDEX].splice(i, 1);
                places_array[PLACE_NORMALIZED_NAMES_INDEX].splice(i, 1);
                i--;
                break;
            }
        }
    }

    //KS- update the remote search portion of the autocompleter, add the
    //number of returned elements to the entryCount -- note that this assumes
    //we set the entryCount before this function is called
    var placeHTML = this.placeArrayToHTML(places_array);
    this.updateChoices(placeHTML, 3);

    //KS- if there are no remote results, display a message letting the user know
    if (this.remoteEntryCount == 0) {
        Element.cleanWhitespace(this.update);
        Element.cleanWhitespace(this.update.childNodes[SKOBEE_PLACES_DIV_INDEX]);
        if (this.localEntryCount == 0) {
            this.update.childNodes[SKOBEE_PLACES_DIV_INDEX].innerHTML = '<ul><li><span class="message">No matches were found in Skobee.</span></li></ul>';
        } else {
            this.update.childNodes[SKOBEE_PLACES_DIV_INDEX].innerHTML = '<ul><li><span class="message">No additional matches were found in Skobee.</span></li></ul>';
        }
    }

    this.stopIndicator();
  },

  show: function() {
    if(Element.getStyle(this.update, 'display')=='none') this.options.onShow(this.element, this.update);
    if(!this.iefix &&
      (navigator.appVersion.indexOf('MSIE')>0) &&
      (navigator.userAgent.indexOf('Opera')<0) &&
      (Element.getStyle(this.update, 'position')=='absolute')) {
      new Insertion.After(this.update,
       '<iframe id="' + this.update.id + '_iefix" '+
       'style="display:none;position:absolute;filter:progid:DXImageTransform.Microsoft.Alpha(opacity=0);" ' +
       'src="javascript:false;" frameborder="0" scrolling="no"></iframe>');
      this.iefix = $(this.update.id+'_iefix');
    }
    if(this.iefix) setTimeout(this.fixIEOverlapping.bind(this), 50);
  },

  fixIEOverlapping: function() {
    Position.clone(this.update, this.iefix);
    this.iefix.style.zIndex = 1;
    this.update.style.zIndex = 2;
    Element.show(this.iefix);
  },

  hide: function() {
    this.stopIndicator();
    if(Element.getStyle(this.update, 'display')!='none') this.options.onHide(this.element, this.update);
    if(this.iefix) Element.hide(this.iefix);
  },

  startIndicator: function() {
    if(this.options.indicator) Element.show(this.options.indicator);
  },

  stopIndicator: function() {
    if(this.options.indicator) Element.hide(this.options.indicator);
  },

  onKeyPress: function(event) {
    if(this.active)
      switch(event.keyCode) {
       case Event.KEY_TAB:
       case Event.KEY_RETURN:
         if (this.entryCount > 0) {
            this.selectEntry();
            Event.stop(event);
         }
       case Event.KEY_ESC:
         this.hide();
         this.active = false;
         Event.stop(event);
         return;
       case Event.KEY_LEFT:
       case Event.KEY_RIGHT:
         return;
       case Event.KEY_UP:
         this.markPrevious();
         this.render();
         if(navigator.appVersion.indexOf('AppleWebKit')>0) Event.stop(event);
         return;
       case Event.KEY_DOWN:
         this.markNext();
         this.render();
         if(navigator.appVersion.indexOf('AppleWebKit')>0) Event.stop(event);
         return;
      }
     else
      if(event.keyCode==Event.KEY_TAB || event.keyCode==Event.KEY_RETURN)
        return;

    this.changed = true;
    this.hasFocus = true;

    if(this.observer) clearTimeout(this.observer);
      this.observer =
        setTimeout(this.onObserverEvent.bind(this), this.options.frequency*1000);
  },

  onHover: function(event) {
    var element = Event.findElement(event, 'LI');
    if(this.index != element.autocompleteIndex)
    {
        this.index = element.autocompleteIndex;
        this.render();
    }
    Event.stop(event);
  },

  onClick: function(event) {
    var element = Event.findElement(event, 'LI');
    this.index = element.autocompleteIndex;
    this.selectEntry();
    this.hide();
  },

  onBlur: function(event) {
    // needed to make click events working
    setTimeout(this.hide.bind(this), 250);
    this.hasFocus = false;
    this.active = false;
  },

  render: function() {
    for (var i = 0; i < this.entryCount; i++)
        this.index==i ?
            Element.addClassName(this.getEntry(i),"selected") :
            Element.removeClassName(this.getEntry(i),"selected");

        if(this.hasFocus) {
            this.show();
            this.active = true;
        }
  },

  markPrevious: function() {
    if(this.index > 0) this.index--
      else this.index = 0;
  },

  markNext: function() {
    if(this.index < this.entryCount-1) this.index++
      else this.index = this.entryCount - 1;
  },

  getEntry: function(index) {
    if (index < this.localEntryCount) {
        return this.update.childNodes[MY_PLACES_DIV_INDEX].firstChild.childNodes[index];
    } else {
        var correctedIndex = index - this.localEntryCount;
        return this.update.childNodes[SKOBEE_PLACES_DIV_INDEX].firstChild.childNodes[correctedIndex];
    }
  },

  getCurrentEntry: function() {
    return this.getEntry(this.index);
  },

  selectEntry: function() {
    this.active = false;
    this.updateElement(this.getCurrentEntry());
    this.afterUpdateElement(this.getCurrentEntry());
  },

  afterUpdateElement: function(selectedElement) {
     $('place_id').value = selectedElement.id;

     //KS- get the place name string minus the <strong></strong> tags
     var placeName = selectedElement.innerHTML.replace(/<strong[^>]*>/i,'').replace(/<\/strong>/i,'');

     $('search_by_name_result_text').innerHTML=placeName.substring(0, 30) + "...";
     flipSearchDisplay('search_by_name_search_panel', 'search_by_name_result_panel', false);
     return false;
  },

  updateElement: function(selectedElement) {
    if (this.options.updateElement) {
      this.options.updateElement(selectedElement);
      return;
    }
    var value = '';
    if (this.options.select) {
      var nodes = document.getElementsByClassName(this.options.select, selectedElement) || [];
      if(nodes.length>0) value = Element.collectTextNodes(nodes[0], this.options.select);
    } else
      value = Element.collectTextNodesIgnoreClass(selectedElement, 'informal');

    var lastTokenPos = this.findLastToken();
    if (lastTokenPos != -1) {
      var newValue = this.element.value.substr(0, lastTokenPos + 1);
      var whitespace = this.element.value.substr(lastTokenPos + 1).match(/^\s+/);
      if (whitespace)
        newValue += whitespace[0];
      this.element.value = newValue + value;
    } else {
      this.element.value = value;
    }
    this.element.focus();

    if (this.options.afterUpdateElement)
      this.options.afterUpdateElement(this.element, selectedElement);
  },

  updateChoices: function(choices, div_index) {
    if(!this.changed && this.hasFocus) {
      Element.cleanWhitespace(this.update);
      Element.cleanWhitespace(this.update.childNodes[div_index]);

      this.update.childNodes[div_index].innerHTML = choices;
      Element.cleanWhitespace(this.update.childNodes[div_index].firstChild);

      if(this.update.childNodes[div_index].firstChild && this.update.childNodes[div_index].firstChild.childNodes) {
        this.updateEntryCount(this.update.childNodes[div_index].firstChild.childNodes.length, div_index);

        var offset = div_index == 1 ? 0 : this.localEntryCount;
        for (var i = offset; i < this.update.childNodes[div_index].firstChild.childNodes.length + offset; i++) {
          var entry = this.getEntry(i);
          Element.cleanWhitespace(entry);
          entry.autocompleteIndex = i;
          this.addObservers(entry);
        }
      } else {
        this.updateEntryCount(0, div_index);
      }

      this.index = 0;
      this.render();
    }
  },

  updateEntryCount: function(num_entries, div_index) {
    if (div_index == MY_PLACES_DIV_INDEX) {
        this.entryCount = num_entries;
        this.localEntryCount = num_entries;
    } else if (div_index == SKOBEE_PLACES_DIV_INDEX) {
        this.entryCount += num_entries;
        this.remoteEntryCount = num_entries;
    }
  },

  addObservers: function(element) {
    Event.observe(element, "mouseover", this.onHover.bindAsEventListener(this));
    Event.observe(element, "click", this.onClick.bindAsEventListener(this));
  },

  onObserverEvent: function() {
    this.changed = false;
    if(this.getToken().length>=this.options.minChars || this.getToken().length>=this.options.minServerSearchChars) {
      this.getUpdatedChoices();
    } else {
      this.active = false;
      this.hide();
    }
  },

  getToken: function() {
    var tokenPos = this.findLastToken();
    if (tokenPos != -1)
      var ret = this.element.value.substr(tokenPos + 1).replace(/^\s+/,'').replace(/\s+$/,'');
    else
      var ret = this.element.value;

    //KS- normalize the string the same way the Place#normalize_string function does it
    ret = ret.replace(/[^a-z0-9 ]/g, '');

    return /\n/.test(ret) ? '' : ret;
  },

  findLastToken: function() {
    var lastTokenPos = -1;

    for (var i=0; i<this.options.tokens.length; i++) {
      var thisTokenPos = this.element.value.lastIndexOf(this.options.tokens[i]);
      if (thisTokenPos > lastTokenPos)
        lastTokenPos = thisTokenPos;
    }
    return lastTokenPos;
  },

  placeArrayToHTML: function(places_array) {
    var ret       = []; // Beginning matches
    var partial   = []; // Inside matches
    var entry     = this.getToken();
    var count     = 0;

    for (var i = 0; i < places_array[PLACE_NAMES_INDEX].length &&
        ret.length < this.options.choices ; i++) {

        var elem = places_array[PLACE_NORMALIZED_NAMES_INDEX][i];
        var display_elem = places_array[PLACE_NAMES_INDEX][i];
        var foundPos = this.options.ignoreCase ?
            elem.toLowerCase().indexOf(entry.toLowerCase()) :
            elem.indexOf(entry);

        while (foundPos != -1) {
            if (foundPos == 0) {
                ret.push("<li id=\"" + places_array[PLACE_IDS_INDEX][i] + "\"><strong>" + display_elem.substr(0, entry.length) + "</strong>" +
                    display_elem.substr(entry.length) + places_array[PLACE_LOCATIONS_INDEX][i] + "</li>");
                break;
            } else if (entry.length >= this.options.partialChars &&
                this.options.partialSearch && foundPos != -1) {
                    if (this.options.fullSearch || /\s/.test(display_elem.substr(foundPos-1,1))) {
                        partial.push("<li id=\"" + places_array[PLACE_IDS_INDEX][i] + "\">" + display_elem.substr(0, foundPos) + "<strong>" +
                            display_elem.substr(foundPos, entry.length) + "</strong>" +
                            display_elem.substr(foundPos + entry.length) + places_array[PLACE_LOCATIONS_INDEX][i] + "</li>");
                        break;
                    }
            }

            foundPos = this.options.ignoreCase ?
                display_elem.toLowerCase().indexOf(entry.toLowerCase(), foundPos + 1) :
                display_elem.indexOf(entry, foundPos + 1);
        }
    }
    if (partial.length)
        ret = ret.concat(partial.slice(0, this.options.choices - ret.length))

    return "<ul>" + ret.join('') + "</ul>";
  },

  setOptions: function(options) {
    this.options = Object.extend({
      choices: 10,
      partialSearch: true,
      partialChars: 1,
      ignoreCase: true,
      fullSearch: false,
      selector: this.placeArrayToHTML.bind(this)
    }, options || {});
  }
}


//MES- A function to populate a control with the contents of an URL
function showUrlInfo(content_ctrl_id, ctrl_id, url_to_content)
{
  if (null != ctrl_id)
  {
    var ctrl = $(ctrl_id);
    //MES- Set a loading message
    ctrl.innerHTML = 'loading...';
    //MES- Disable the onclick handler
    ctrl.onclick = function(){ return false; };
  }
  //MES- Get the URL and put it into the correct place
  new Ajax.Updater(content_ctrl_id, url_to_content, {asynchronous:true, onFailure:handleFail, evalScripts:true});
}

function addToRemoveField(login_name) {
  if(editor_open && Element.visible('plan_who_editor')){
    if ($('remove_who_div') == undefined){
      new Insertion.Bottom('remove_who_row_field', '<div id="remove_who_div"><textarea disabled="disabled" class="big_form" id="plan_remove_who_disabled" name="plan_remove_who_disabled" rows="3" cols="54"></textarea><input type="hidden" name="plan_remove_who" id="plan_remove_who"/></div>');
    }
    $('plan_remove_who_disabled').value = $('plan_remove_who_disabled').value + login_name + ', ';
    $('plan_remove_who').value = $('plan_remove_who').value + login_name + ', ';
    return false;
  } else {
    return true;
  }
}