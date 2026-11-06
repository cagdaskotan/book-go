-- Her rafa eklenen kitabın o raftaki görünüm biçimi:
--   'spine' (yandan sırt, varsayılan), 'face' (kapağı öne dönük),
--   'stack' (yatay, üst üste yığın).
ALTER TABLE collection_books
  ADD COLUMN display_mode VARCHAR(10) NOT NULL DEFAULT 'spine';
