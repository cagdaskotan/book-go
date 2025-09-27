ALTER TABLE books
  ADD COLUMN started_at DATE NULL,
  ADD COLUMN finished_at DATE NULL,
  ADD COLUMN is_finished TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN current_page INT UNSIGNED NOT NULL DEFAULT 0,
  ADD COLUMN notes TEXT NULL,
  ADD COLUMN favorite TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN tags VARCHAR(255) NULL,
  ADD INDEX idx_books_user_status (user_id, is_finished),
  ADD INDEX idx_books_user_title (user_id, title);
