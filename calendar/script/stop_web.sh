#! /bin/sh -
kill `cat /home/skobee/code/extranet/calendar/log/lighttpd.pid`
cd /home/skobee/code/extranet/calendar
scgi_cluster stop
