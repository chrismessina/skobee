// ==UserScript==
// @name          Yahoo! Local Skobee Info
// @namespace     http://www.skobee.com/greasemonkey
// @description	  Adds info to the Yahoo! Local page
// @include       http://local.yahoo.com/*
// ==/UserScript==

/*
MES- This is a GreaseMonkey script that demonstrates one possible way that
Skobee could be incorporated into Yahoo! Local.  It's 100% hardcoded.  The data,
however, is "softcoded" in the sense that it's stored in arrays in the source code.
To modify the contents of the demo, simply change the contents of the arrays below.
Comments on each array describe the format of the array.
*/


/*
MES- Stuff for the "Photos taken here" sidebar
*/

var new_div = document.createElement("div");
new_div.setAttribute("class", "ylsdefbx");

var heading = document.createElement("h4");
heading.setAttribute("class", "ylsclr3");
var txt = document.createTextNode("Photos taken here:");
heading.appendChild(txt);
new_div.appendChild(heading);

//MES- Figure out what place we're showing
var pattern = /[?&]id=([0-9]+)/;
var res = pattern.exec(document.location);
//MES- Choose some default
var place_id = '28795535'
if (null != res)
{
  place_id = res[1]
}

//MES- The photos array contains info about the photos we'll show.  Each
//  sub-item is an array.  The first item in the array is the URL to the
//  thumbnail for the photo on Flickr (with the leading 'http://static.flickr.com/'
//  removed.)  The second item is the URL to the main page for the photo (with
//  the leading 'http://www.flickr.com/photos/ removed.)
var photos = [];
switch (place_id)
{
  case '21349059':  //MES- Gary Danko
    photos = [
      ['15/19003586_b6c7f1118c_s.jpg', 'cygnoir/19003586/in/photostream/'],
      ['12/19003585_7cbb5a8a48_s.jpg', 'cygnoir/19003585/in/photostream/'],
      ['11/12483730_cdb283d22c_s.jpg', 'coreycfake/12483730/in/photostream/'], 
      ['54/127035002_03e28f3b63_s.jpg', 'mondo1227/127035002/in/photostream/'],
      ['44/127034989_8e08080e46_s.jpg', 'mondo1227/127034989/in/photostream/'],
      ['41/84245346_c5b118d8bd_s.jpg', 'uvince/84245346/in/photostream/']
    ];
    break;
  case '26935035':  //MES- Coupa Cafe
      photos = [
        ['49/109521534_6af4216871_s.jpg', 'kbibb/109521534/in/photostream/'],
        ['28/94736855_341628a423_s.jpg', 'courtneypix/94736855/in/photostream/'],
        ['25/94736883_7259a7bb9b_s.jpg', 'courtneypix/94736883/in/photostream/'],
        ['34/94736924_214acb7f31_s.jpg', 'courtneypix/94736924/in/photostream/'],
        ['52/139270356_e2870a0012_s.jpg', '45688285@N00/139270356/in/set-72057594123457303/'],
        ['43/116669724_bf3abe727e_s.jpg', 'brianoberkirch/116669724/in/photostream/']
      ];
    break;
    case '32571469':  //MES- Tres Agaves
        photos = [
          ['25/63132962_e08781c5a6_s.jpg', 'pallo/63132962/in/photostream/'],
          ['26/63132965_01cd62ca18_s.jpg', 'pallo/63132965/in/photostream/'],
          ['27/52631236_15179ce13d_s.jpg', 'bbum/52631236/in/photostream/'],
          ['27/52631486_f6ac2b4f45_s.jpg', 'bbum/52631486/in/photostream/'],
          ['50/129011580_9de5ef2870_s.jpg', '92358359@N00/129011580/in/photostream/'],
          ['52/129021177_8545907940_s.jpg', '92358359@N00/129021177/in/photostream/']
        ];
    break;
  default:
    photos = [
      ['54/147751978_fd229fe0ca_s.jpg', 'we_are_joker/147751978/'],
      ['55/147751985_efc6c12414_s.jpg', 'swizzlestudio/147751985/'],
      ['46/147752126_484a3c46d4_s.jpg', 'swizzlestudio/147752126/in/photostream/']
    ];
    break;
}

var tblNode = document.createElement('table');
tblNode.setAttribute('border', '0');
tblNode.setAttribute('cellspacing', '2');
tblNode.setAttribute('width', '100%');
new_div.appendChild(tblNode);


var trNode = null
//MES- Iterate through the pictures, adding each one
for (var idx = 0; idx < photos.length; ++idx)
{
  //MES- A row contains two images
  var new_row = false
  if (0 == idx % 2)
  {
    trNode = document.createElement('tr');
    tblNode.appendChild(trNode);
  }
  
  //MES- Put in the td
  var tdNode = document.createElement('td');
  tdNode.setAttribute('align', 'center');
  tdNode.setAttribute('width', '25%');
  trNode.appendChild(tdNode);
  
  
  //MES- Put in an anchor for the photo
  var urlNode = document.createElement("a");
  urlNode.setAttribute("href", "http://www.flickr.com/photos/" + photos[idx][1]);
  urlNode.setAttribute("target", "flickr");
  tdNode.appendChild(urlNode);
  
  //MES- And put in the actual image
  var photoNode = document.createElement('img');
  photoNode.setAttribute('src', 'http://static.flickr.com/' + photos[idx][0]);
  urlNode.appendChild(photoNode);
}

//MES- Find the div with ID ylssidebar
var maindiv = document.getElementById('ylssidebar');
var defbx = maindiv.childNodes[2];
maindiv.insertBefore(new_div, defbx);


/*
MES- Stuff for the "Friends who have attended" section
*/

new_div = document.createElement("div");
new_div.setAttribute("class", "ylsmrinfo");

heading = document.createElement("h2");
heading.setAttribute("class", "ylshr");
txt = document.createTextNode("Friends who have attended recently");
heading.appendChild(txt);
new_div.appendChild(heading);


//MES- The friends array contains info about the friends we'll show in the "Friends
//  who have recently attended" section.  Each entry in the array contains info about
//  one friend.  Each friend item is itself an array, containing:
//    The Skobee login of the friend
//    The Plan ID of the plan to be displayed
//    The filename for the thumbnail for the user (the URL without the 'http://www.skobee.com/pictures/show/')
//    The name of the plan
//    An array of the Skobee logins of the other attendees (which will be hyperlinks)
//    The number of days in the past that the plan was
var friends = [];
switch (place_id)
{
  case '21349059':  //MES- Gary Danko
    friends = [
     ['kavin', 3444, '2666.jpg', 'Bar hopping the sunset', ['noaml', 'allenc', 'meghans'], 3],
     ['kristen', 1274, '28.jpg', 'Girls night out', ['sally', 'mary', 'jane'], 4],
     ['sookoun', 3405, '1430.jpg', "Angie's 21st Birthday", ['james', 'angie', 'jane', 'michaels', 'house'], 6],
     ['squidox', 3392, '78.JPG', "UCSF Happy Hour", ['bob', 'bill', 'jane', 'michaels', 'house', 'kavin', 'allenc', 'meghans', 'sally', 'mary'], 8]
    ];
    break;
  case '26935035':  //MES- Coupa Cafe
    friends = [
     ['ifindkarma', 89, '56.jpg', 'Get together', ['noaml', 'troutgirl'], 3],
     ['emstraus', 25, '46.jpg', "Erica's done with boards!", ['dbrosen', 'aschapm', 'raajkumar', 'mcudich', 'michael_daley'], 8],
     ['tryptopham', 318, '2708.jpg', "Coffee & chicken", ['mcudich', 'dbrosen', 'megpriley', 'lukatmyshu', 'house'], 6],
     ['megpriley', 30, '990.JPG', "Streets of Chaos Art Show", ['scott_grant', 'kristen', 'kavin', 'aschapm', 'house', 'kavin', 'allenc', 'meghans', 'sally', 'mary'], 8]
    ];
    break;
  case '32571469':  //MES- Tres Agaves
    friends = [
     ['mcudich', 1460, '16.jpg', 'The plan that never was', ['aschapm', 'tryptopham', 'chart'], 3],
     ['kristen', 1274, '28.jpg', 'Girls night out', ['sally', 'mary', 'jane'], 4],
     ['sookoun', 3405, '1430.jpg', "Angie's 21st Birthday", ['james', 'angie', 'jane', 'michaels', 'house'], 6],
     ['squidox', 3392, '78.JPG', "UCSF Happy Hour", ['bob', 'bill', 'jane', 'michaels', 'house', 'kavin', 'allenc', 'meghans', 'sally', 'mary'], 8]
    ];
    break;
  default:
    friends = [
      ['kavin', 3444, '2666.jpg', 'Bar hopping the sunset', ['noaml', 'allenc', 'meghans'], 3],
      ['kristen', 1274, '28.jpg', 'Girls night out', ['sally', 'mary', 'jane'], 4],
      ['sookoun', 3405, '1430.jpg', "Angie's 21st Birthday", ['james', 'angie', 'jane', 'michaels', 'house'], 6],
      ['squidox', 3392, '78.JPG', "UCSF Happy Hour", ['bob', 'bill', 'jane', 'michaels', 'house', 'kavin', 'allenc', 'meghans', 'sally', 'mary'], 8]
    ];
    break;
}

var tblNode = document.createElement('table');
tblNode.setAttribute('border', '0');
tblNode.setAttribute('cellspacing', '2');
tblNode.setAttribute('width', '100%');
new_div.appendChild(tblNode);


var trNode = null
//MES- Iterate through the friends, adding each one
for (var idx = 0; idx < friends.length; ++idx)
{
  //MES- A row contains two friends
  var new_row = false
  if (0 == idx % 2)
  {
    trNode = document.createElement('tr');
    tblNode.appendChild(trNode);
  }
  
  //MES- Put in the td
  var tdNode = document.createElement('td');
  trNode.appendChild(tdNode);
  
  //MES- There's a table for each user, with two TDs
  var subtblNode = document.createElement('table');
  tdNode.appendChild(subtblNode);
  var subtrNode = document.createElement('tr');
  subtblNode.appendChild(subtrNode);
  
  //MES- The left TD contains a picture of the user, and their login
  var subtdNode = document.createElement('td');
  subtrNode.appendChild(subtdNode);
  
  
  //MES- Put in an anchor for the photo
  var urlNode = document.createElement("a");
  urlNode.setAttribute("href", "http://www.skobee.com/user/" + friends[idx][0]);
  urlNode.setAttribute("target", "skobee");
  subtdNode.appendChild(urlNode);
  
  //MES- And put in the actual image
  var photoNode = document.createElement('img');
  photoNode.setAttribute('src', 'http://www.skobee.com/pictures/show/' + friends[idx][2]);
  urlNode.appendChild(photoNode);
  
  //MES- As well as a br and the login
  var brNode = document.createElement('br');
  subtdNode.appendChild(brNode);
  
  var urlNode = document.createElement("a");
  urlNode.setAttribute("href", "http://www.skobee.com/user/" + friends[idx][0]);
  urlNode.setAttribute("target", "skobee");
  subtdNode.appendChild(urlNode);
  var loginTxt = document.createTextNode(friends[idx][0]);
  urlNode.appendChild(loginTxt);
  
  
  //MES- The right TD contains a description of the event
  subtdNode = document.createElement('td');
  subtdNode.setAttribute("valign", "top");
  subtrNode.appendChild(subtdNode);
  
  var evtANode = document.createElement('a');
  evtANode.setAttribute('href', 'http://www.skobee.com/plans/show/' + friends[idx][1]);
  evtANode.setAttribute("target", "skobee");
  subtdNode.appendChild(evtANode);
  var evtTxt = document.createTextNode(friends[idx][3]);
  evtANode.appendChild(evtTxt);
  brNode = document.createElement('br');
  subtdNode.appendChild(brNode);
  
  var attendees = friends[idx][4];
  var len_to_show = attendees.length
  if (3 < len_to_show)
  {
    len_to_show = 2;
  }
  for (var attidx = 0; attidx < len_to_show; ++attidx)
  {
    if (0 != attidx)
    {
      var commaNode = document.createTextNode(', ');
      subtdNode.appendChild(commaNode);
    }
    var attendeeANode = document.createElement('a');
    attendeeANode.setAttribute("target", "skobee");
    attendeeANode.setAttribute('href', 'http://www.skobee.com/user/' + attendees[attidx]);
    subtdNode.appendChild(attendeeANode);
    var attendeeTxtNode = document.createTextNode(attendees[attidx]);
    attendeeANode.appendChild(attendeeTxtNode);     
  }
  if (len_to_show < attendees.length)
  {
    var moreNode = document.createTextNode(', and ' + (attendees.length - len_to_show) + ' more');
    subtdNode.appendChild(moreNode);
  }
  
  brNode = document.createElement('br');
  subtdNode.appendChild(brNode);
  
  var days_ago = friends[idx][5];
  var txt_days_ago = days_ago + ' days ago';
  if (1 == days_ago)
    txt_days_ago = 'one day ago';
  
  var timeI = document.createElement('i');
  subtdNode.appendChild(timeI);
  var timeTxt = document.createTextNode(txt_days_ago);
  timeI.appendChild(timeTxt);
  
  //MES- Add the 'was it fun' item
  brNode = document.createElement('br');
  subtdNode.appendChild(brNode);
  var funANode = document.createElement('a');
  funANode.setAttribute("target", "skobee");
  funANode.setAttribute('href', 'http://www.skobee.com');
  subtdNode.appendChild(funANode);
  var funBNode = document.createElement('b');
  funANode.appendChild(funBNode);
  var funTxt = document.createTextNode('Was it fun?');
  funBNode.appendChild(funTxt);
}


var editorial_div = getElementByTagAndClass('div', 'ylsmrinfo', 1);
editorial_div.parentNode.insertBefore(new_div, editorial_div);




function getElementByTagAndClass(tag_str, class_str, desired_idx)
{
  var elems = document.getElementsByTagName(tag_str);
  var item_idx = 0;
  for (var idx = 0; idx < elems.length; ++idx)
  {
    var elem = elems[idx];
    if (class_str == elem.getAttribute('class'))
    {
      if (item_idx == desired_idx)
        return elem;
        
      item_idx += 1;
    }
  }
}