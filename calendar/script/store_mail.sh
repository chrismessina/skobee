#!/bin/sh
WRITEFILE=`mktemp /home/skobee/code/extranet/calendar/mail_queue/writing.XXXXXXXXXX`
cat > $WRITEFILE
PATTERN=/home/skobee/code/extranet/calendar/mail_queue/writing.
EXT="${WRITEFILE#$PATTERN}"
OUTFILE='/home/skobee/code/extranet/calendar/mail_queue/email.'${EXT}
mv --backup=t "$WRITEFILE" "$OUTFILE"
