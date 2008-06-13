#! /bin/sh -
echo "Starting boot commands for skobee"
date
. ~/.job_env
/usr/local/sbin/lighttpd -f /home/skobee/code/extranet/calendar/config/lighttpd.conf
cd /home/skobee/code/extranet/calendar
scgi_cluster start
