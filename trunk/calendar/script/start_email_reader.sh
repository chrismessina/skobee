#!/bin/sh
. ~/.job_env
echo "Starting email reader"
date
cd /home/skobee/code/extranet/calendar
ruby script/runner 'Mailman.receive_emails_from_files("/home/skobee/code/extranet/calendar/mail_queue", "/home/skobee/code/extranet/calendar/handled_mail")'
