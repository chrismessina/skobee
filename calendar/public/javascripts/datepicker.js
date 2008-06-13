/* ANSI Datepicker Planner - David Lee 2005

  david [at] davelee [dot] com [dot] au

  project homepage: http://projects.exactlyoneturtle.com/date_picker/

  License:
  use, modify and distribute freely as long as this header remains intact;
  please mail any improvements to the author
*/

var DatePicker = {
  version: 0.31,

  /* Configuration options */

  // if false, hide last row if empty
  constantHeight: true,

  // show select list for year?
  useDropForYear: false,

  // show select list for month?
  useDropForMonth: false,

  // number of years before current to show in select list
  yearsPriorInDrop: 10,

  // number of years after current to show in select list
  yearsNextInDrop: 10,

  // The current year
  year: new Date().getFullYear(),

  // The first day of the week (0=Sunday, 1=Monday, ...)
  firstDayOfWeek: 0,

  // show only 3 chars for month in link
  abbreviateMonthInLink: true,

  // show only 2 chars for year in link
  abbreviateYearInLink: false,

  // eg 1st
  showDaySuffixInLink: false,

  // eg 1st; doesn't play nice w/ month selector
  showDaySuffixInPlanner: false,

  // px size written inline when month selector used
  largeCellSize: 22,

  // if set, choosing a day will send the date to this URL, eg 'someUrl?date='
  urlBase: null,

  // show a cancel button to revert choice
  showCancelLink: true,

  // stores link text to revert to when cancelling
  _priorLinkText: [],

  // stores date before datepicker to revert to when cancelling
  _priorDate: [],

  _displayID: null,

  months: 'January,February,March,April,May,June,July,August,September,October,November,December'.split(','),

  days: 'S,M,T,W,T,F,S'.split(','),

  //MGS- global for storing elements we are mucking with
  relativelyPositionedElements: [],

  /* Method declarations */

  toggleDatePicker: function (id, displayID) {
    var planner = this.findPlannerElement(id);
    if (planner.style.display == 'block') {  // If showing, hide
      planner.style.display = 'none';
      DatePicker.restoreRelativePositioning();
    } else {                                  // Else, show
      planner.style.display = 'block';
      this._priorLinkText[id] = this.findLinkElement(id).innerHTML;
      this._priorDate[id] = document.getElementById(id).value;
      this._displayID = displayID;
      this.writePlanner(id);
      //MGS- because of IE z-index/relatively/absolutely positioned elements positioning problems,
      // we need to do some hacking here;  while the datepicker is displayed, remove the relative
      // style from all other elements in this page; when the datepicker is closed....add the relative
      // style back to those elements
      relativelyPositionedElements = document.getElementsByClassName('relative');
            for (var i=0;i<relativelyPositionedElements.length;i++){
              if ((relativelyPositionedElements[i].id != 'time-div') && (relativelyPositionedElements[i].id != 'date-div')) {
                Element.removeClassName(relativelyPositionedElements[i],'relative');
              } else {
                relativelyPositionedElements = relativelyPositionedElements.without(relativelyPositionedElements[i]);
              }
      }
      //MGS- end hack
    }
  },

  //MGS- add the relatively positioned elements styles back
  restoreRelativePositioning: function (){
    for (var i=0;i<relativelyPositionedElements.length;i++){
      Element.addClassName(relativelyPositionedElements[i],'relative');
    }
  },

  cancel: function (id) {
    DatePicker.restoreRelativePositioning();
    this.findLinkElement(id).innerHTML = this._priorLinkText[id];
    document.getElementById(id).value = this._priorDate[id];
    this.findPlannerElement(id).style.display = 'none';
  },

  // mitigate clipping when new month has less days than selected date
  unclipDates: function (d1, d2) {
    if (d2.getDate() != d1.getDate()) {
      d2 = new Date(d2.getFullYear(), d2.getMonth(), 0);
    }

    return d2;
  },

  // change date given an offset from the current date as a number of months (+-)
  changePlanner: function (id, offset) {
    var d1 = this.getSelectedDate(id), d2;
    if (offset % 12 == 0) { // 1 year forward / back (fix Safari bug)
      d2 = new Date (d1.getFullYear() + offset / 12, d1.getMonth(), d1.getDate() );
    } else if (d1.getMonth() == 0 && offset == -1) {// tiptoe around another Safari bug
      d2 = new Date (d1.getFullYear() - 1, 11, d1.getDate() );
    } else {
      d2 = new Date (d1.getFullYear(), d1.getMonth() + offset, d1.getDate() );
    }

    d2 = this.unclipDates(d1, d2);
    ansi_date = d2.getFullYear() + '-' + (d2.getMonth() + 1) + '-' + d2.getDate();
    this.setDate(id, ansi_date);
    this.writePlanner(id);
  },

  setDate: function (id, ansiDate) {
    DatePicker.restoreRelativePositioning();
    var d_day  = (this.showDaySuffixInLink ? this.formatDay(ansiDate.split('-')[2]) : ansiDate.split('-')[2]);
    var d_year = (this.abbreviateYearInLink ? ansiDate.split('-')[0].substring(2,4) : ansiDate.split('-')[0]);
    var d_mon  = this.getMonthName(Number(ansiDate.split('-')[1])-1);
    var d_mon  = Number(ansiDate.split('-')[1]) + '';
    if (this.abbreviateMonthInLink) { d_mon = d_mon.substring(0, 3); }
    document.getElementById(id).value = ansiDate;
    document.getElementById('date_year').value = d_year;
    document.getElementById('date_month').value = d_mon;
    document.getElementById('date_day').value = d_day;
    //document.getElementById(this._displayID).value = d_mon + '/' + d_day + '/' + d_year;
    //this.findLinkElement(id).innerHTML = d_day + ' ' + d_mon + ' ' +  d_year;
  },

  pickDate: function (id, ansi_date) {
    this.setDate(id, ansi_date);
    this.toggleDatePicker(id);
    if (this.urlBase) {
      document.location.href = this.urlBase + ansi_date
    }
  },

  getMonthName: function(monthNum) { //anomalous
    return this.months[monthNum];
  },

  dateFromAnsiDate: function (ansi_date) {
    return new Date(ansi_date.split('-')[0], Number(ansi_date.split('-')[1]) - 1, ansi_date.split('-')[2])
  },

  ansiDateFromDate: function(date) {
    alert( date.getFullYear() + '-' + (date.getMonth()+1) + '-' + date.getDate() );
  },

  getSelectedDate: function (id) {
    if (document.getElementById(id).value == '') return new Date(); // default to today if no value exists
    return this.dateFromAnsiDate(document.getElementById(id).value);
  },

  makeChangePlannerLink: function (id, label, offset) {
    return ('<a href="#" id="change_planner" onclick="DatePicker.changePlanner(\''+id+'\','+offset+')">' + label + '</a>');
  },

  formatDay: function (n) {
    var x;
    switch (String(n)){
      case '1' :
      case '21': case '31': x = 'st'; break;
      case '2' : case '22': x = 'nd'; break;
      case '3' : case '23': x = 'rd'; break;
      default:
        x = 'th';
    }

    return n + x;
  },

  writeMonth: function (id, n) {
    if (this.useDropForMonth) {
      var opts = '';
      for (i in this.months) {
        sel = (i == this.getSelectedDate(id).getMonth() ? 'selected="selected" ' : '');
        opts += '<option ' + sel + 'value="'+ i +'">' + this.getMonthName(i) + '</option>';
      }

      return '<select onchange="DatePicker.selectMonth(\'' + id + '\', this.value)">' + opts + '</select>';
    } else {
      return this.getMonthName(n)
    }
  },

  writeYear: function (id, n) {
    if (this.useDropForYear) {
      var min = this.year - this.yearsPriorInDrop;
      var max = this.year + this.yearsNextInDrop;
      var opts = '';
      for (i = min; i < max; i++) {
        sel = (i == this.getSelectedDate(id).getFullYear() ? 'selected="selected" ' : '');
        opts += '<option ' + sel + 'value="'+ i +'">' + i + '</option>';
      }

      return '<select onchange="DatePicker.selectYear(\'' + id + '\', this.value)">' + opts + '</select>';
    } else {
      return n
    }
  },

  selectMonth: function (id, n) {
    d = this.getSelectedDate(id)
    d2 = new Date(d.getFullYear(), n, d.getDate())
    d2 = this.unclipDates(d, d2)
    this.setDate(id, d2.getFullYear() + '-' + (Number(n)+1) + '-' + d2.getDate() )
    this.writePlanner(id)
  },

  selectYear: function (id, n) {
    d = this.getSelectedDate(id)
    d2 = new Date(n, d.getMonth(), d.getDate())
    d2 = this.unclipDates(d, d2)
    this.setDate(id, n + '-' + (d2.getMonth()+1) + '-' + d2.getDate() )
    this.writePlanner(id)
  },

  writePlanner: function (id) {
    var date = this.getSelectedDate(id);
    var firstWeekday = new Date(date.getFullYear(), date.getMonth(), 1).getDay();
    var lastDateOfMonth = new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
    var day  = 1; // current day of month

    // not quite entirely pointless: fix Safari display bug with absolute positioned div
    this.findLinkElement(id).innerHTML = this.findLinkElement(id).innerHTML;

    var o = '<table cellspacing="0">'; // start output buffer
    o += '<thead><tr>';

    // month buttons
    o +=
      '<th style="text-align:left">' + this.makeChangePlannerLink(id,'&lt;',-1) + '</th>' +
      '<th colspan="5">' +      //(this.showDaySuffixInPlanner ? this.formatDay(date.getDate()) : date.getDate()) +
      ' ' + this.writeMonth(id, date.getMonth()) + '</th>' +
      '<th style="text-align:right">' + this.makeChangePlannerLink(id,'&gt;',1) + '</th>';
    o += '</tr><tr>';

    // year buttons
    o +=
      '<th colspan="2" style="text-align:left">' + this.makeChangePlannerLink(id,'&lt;&lt;',-12) + '</th>' +
      '<th colspan="3">' + this.writeYear(id,  date.getFullYear()) + '</th>' +
      '<th colspan="2" style="text-align:right">' + this.makeChangePlannerLink(id,'&gt;&gt;',12) + '</th>';
    o += '</tr><tr class="day_labels">';

    // day labels
    for(var i = 0; i < this.days.length; i++) {
      o += '<th>' + this.days[(i+this.firstDayOfWeek) % 7] + '</th>';
    }
    o += '</tr></thead>';

    if (this.showCancelLink) {
      o += '<tfoot><tr><td colspan="7"><a href="#" onclick="DatePicker.cancel(\''+id+'\')">Close</a></td></tr></tfoot>';
    }

    // day grid
    o += '<tbody>';
    for(rows = 1; rows < 7 && (this.constantHeight || day < lastDateOfMonth); rows++) {
      o += '<tr>';
      for(var day_num = 0; day_num < this.days.length; day_num++) {
        var translated_day = (this.firstDayOfWeek + day_num) % 7
        if ((translated_day >= firstWeekday || day > 1) && (day <= lastDateOfMonth) ) {
          args = [id, (date.getFullYear() + '-' + (date.getMonth() + 1) + '-' + day)];
          style = (this.selectMonth ? 'style="width: ' + this.largeCellSize + 'px"' : '');
          o +=
            '<td ' + style + '>' + // link : each day
            "<a href=\"#\" id=\"day"+day+"\" onclick=\"DatePicker.pickDate('" + args.join("','") + "'); return false;\">" + day + '</a>' +
            '</td>';
          day++;
        } else {
          o += '<td>&nbsp;</td>';
        }
      }

      o += '</tr></tbody>';
    }

    o += '</table>';

    this.findPlannerElement(id).innerHTML = o;
  },

  findPlannerElement: function(id) {
    return document.getElementById(id + '_planner');
  },

  findLinkElement: function(id) {
    return document.getElementById(id + '_link');
  }
};
