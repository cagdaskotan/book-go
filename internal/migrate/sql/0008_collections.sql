CREATE TABLE IF NOT EXISTS collections (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id INT UNSIGNED NOT NULL,
  name VARCHAR(80) NOT NULL,
  color VARCHAR(10) NOT NULL DEFAULT '#6750E8',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_collections_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_collections_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS collection_books (
  collection_id BIGINT UNSIGNED NOT NULL,
  book_id INT UNSIGNED NOT NULL,
  added_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (collection_id, book_id),
  CONSTRAINT fk_collection_books_collection
    FOREIGN KEY (collection_id) REFERENCES collections(id) ON DELETE CASCADE,
  CONSTRAINT fk_collection_books_book
    FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
