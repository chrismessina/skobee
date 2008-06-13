ALTER TABLE plans ADD COLUMN salt varchar(40) NOT NULL default '' AFTER local_start;
