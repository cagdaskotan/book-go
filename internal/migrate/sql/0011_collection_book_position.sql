-- Rafta kitapların manuel sırası. 0 = sıralanmamış (eklenme tarihine düşer).
ALTER TABLE collection_books
  ADD COLUMN position INT NOT NULL DEFAULT 0;
