#KS- create a new column that we'll use to hold the new values temporarily
ALTER TABLE user_atts ADD COLUMN att_id_temp int NOT NULL AFTER att_id;

#KS- convert the old values to new values
UPDATE user_atts SET att_id_temp = 1 WHERE att_id = 'work address';
UPDATE user_atts SET att_id_temp = 2 WHERE att_id = 'home address';
UPDATE user_atts SET att_id_temp = 3 WHERE att_id = 'mobile phone';
UPDATE user_atts SET att_id_temp = 4 WHERE att_id = 'birthday';
UPDATE user_atts SET att_id_temp = 5 WHERE att_id = 'aol im';
UPDATE user_atts SET att_id_temp = 6 WHERE att_id = 'yahoo im';
UPDATE user_atts SET att_id_temp = 7 WHERE att_id = 'msn im';
UPDATE user_atts SET att_id_temp = 8 WHERE att_id = 'icq im';
UPDATE user_atts SET att_id_temp = 9 WHERE att_id = 'gtalk im';
UPDATE user_atts SET att_id_temp = 10 WHERE att_id = 'remind by email';
UPDATE user_atts SET att_id_temp = 11 WHERE att_id = 'remind by sms';
UPDATE user_atts SET att_id_temp = 12 WHERE att_id = 'invite notification option';
UPDATE user_atts SET att_id_temp = 13 WHERE att_id = 'plan modified notification option';
UPDATE user_atts SET att_id_temp = 14 WHERE att_id = 'confirmed plan reminder option';
UPDATE user_atts SET att_id_temp = 15 WHERE att_id = 'reminder min';
UPDATE user_atts SET att_id_temp = 16 WHERE att_id = 'added as friend notification option';
UPDATE user_atts SET att_id_temp = 17 WHERE att_id = 'security';

#KS- drop the old column
ALTER TABLE user_atts DROP COLUMN att_id;

#KS- rename the new column
ALTER TABLE user_atts CHANGE att_id_temp att_id int NOT NULL;