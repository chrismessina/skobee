#!/bin/sh
LOCKFILE=/home/skobee/code/extranet/calendar/script/nightly_job.lock
#MES- If the lockfile already exists, then this job is already running, exit
[ -f $LOCKFILE ] && exit 0

#MES- Delete the lockfile whenever we exit
trap "{ rm -f $LOCKFILE ; exit 255; }" EXIT

#MES- Make the lockfile
touch $LOCKFILE

echo "Starting nightly job"
date
. ~/.job_env
cd /home/skobee/code/extranet/calendar
ruby script/runner 'User.nightly_tasks'
exit 0
