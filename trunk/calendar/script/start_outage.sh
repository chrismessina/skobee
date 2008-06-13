#! /bin/sh -
echo "Starting the 'outage' web server"
/usr/local/sbin/lighttpd -f /home/skobee/code/extranet/calendar/config/lighttpd_outage.conf
