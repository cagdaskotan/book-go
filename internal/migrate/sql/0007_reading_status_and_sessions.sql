ALTER TABLE books
  ADD COLUMN reading_status VARCHAR(24) NOT NULL DEFAULT 'want_to_read' AFTER is_finished,
  ADD INDEX idx_books_user_reading_status (user_id, reading_status);

UPDATE books
SET reading_status = CASE
  WHEN is_finished = 1 THEN 'finished'
  WHEN current_page > 0 THEN 'reading'
  ELSE 'want_to_read'
END;

ALTER TABLE reading_logs
  ADD COLUMN duration_minutes INT UNSIGNED NOT NULL DEFAULT 0 AFTER pages_read;
