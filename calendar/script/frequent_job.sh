#!/bin/sh
LOCKFILE=/home/skobee/code/extranet/calendar/script/frequent_job.lock
#MES- If the lockfile already exists, then this job is already running, exit
[ -f $LOCKFILE ] && exit 0

#MES- Delete the lockfile whenever we exit
trap "{ rm -f $LOCKFILE ; exit 255; }" EXIT

#MES- Make the lockfile
touch $LOCKFILE

echo "Starting frequent job"
date
. ~/.job_env
cd /home/skobee/code/extranet/calendar
ruby script/runner 'User.frequent_tasks'
exit 0
