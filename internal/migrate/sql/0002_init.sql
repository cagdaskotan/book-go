ALTER TABLE users
  ADD COLUMN password_hash VARCHAR(255) NULL,
  ADD INDEX idx_users_email (email);
