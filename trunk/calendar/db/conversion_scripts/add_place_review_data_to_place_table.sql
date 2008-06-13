ALTER TABLE places ADD COLUMN average_rating int default NULL;
ALTER TABLE places ADD COLUMN total_ratings int default 0 AFTER average_rating;
ALTER TABLE places ADD COLUMN total_reviews int default 0 AFTER total_ratings;
ALTER TABLE places ADD COLUMN last_review_date datetime default NULL AFTER total_reviews;