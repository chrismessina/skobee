ALTER TABLE places ADD COLUMN click_url varchar(512) DEFAULT NULL AFTER url;
ALTER TABLE places ADD COLUMN yahoo_url varchar(512) DEFAULT NULL AFTER click_url;
ALTER TABLE places ADD COLUMN yahoo_click_url varchar(512) DEFAULT NULL AFTER yahoo_url;