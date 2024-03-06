-- A table to store multiple records for each long text string
-- Postgres text search has many limitations when used for arbitrarily long text
-- Doing it this way means we can search strings of any length

-- Table Definition ----------------------------------------------

CREATE TABLE file_text_indices (
  file_text_index_id SERIAL PRIMARY KEY,
  file_id INTEGER NOT NULL REFERENCES files(file_id) ON DELETE CASCADE,
  sequence_no INTEGER
  content_tsv TSVECTOR,
  content text
);

-- Indices -------------------------------------------------------

CREATE INDEX IF NOT EXISTS file_text_indices_content_tsv_file_id_idx
  ON file_text_indices
  USING GIN (file_id, content_tsv);

-- Grants --------------------------------------------------------

GRANT ALL ON TABLE file_text_indices TO ${db_user};
GRANT ALL ON SEQUENCE file_text_indices_file_text_index_id_seq TO ${db_user};

-- Separate long strings into smaller tsvectors
-- Need to avoid all of these issues: 
   https://www.postgresql.org/docs/14/textsearch-limitations.html
-- Trigger Function for AFTER UPDATE/INSERT on file_text
-- Clear any existing TSVector records, and add the smaller chunks to the index
CREATE OR REPLACE FUNCTION split_file_text_to_file_indices() RETURNS trigger
AS $update_file_text_to_file_indices$
DECLARE num_spaces INT;
BEGIN
  DELETE FROM file_text_indices WHERE file_id = NEW.file_id;

  INSERT INTO file_text_indices (file_id, content_tsv, content)
    SELECT file_id, to_tsvector(content), content
      FROM (SELECT NEW.file_id, LARGE_TEXT_TO_TSVECTORS(NEW.file_text) as content) AS frags
      WHERE content IS NOT NULL;

  RETURN NULL;
END;
$update_file_text_to_file_indices$
LANGUAGE plpgsql;

-- Add the trigger to the files table file_text column
CREATE TRIGGER t_update_file_text_tsv
AFTER INSERT OR UPDATE OF file_text ON files
FOR EACH ROW EXECUTE FUNCTION split_file_text_to_file_indices();
