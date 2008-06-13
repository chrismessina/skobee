#MES- Add a column to plans to hold the timeperiod for the plan

ALTER TABLE `plans` ADD COLUMN `timeperiod` int(11) default 0;
UPDATE plans SET timeperiod = -1;

#MES- You must run an upgrade script to populate the column
#	Run "ruby script/runner -e production Plan.upgrade_timeperiods"