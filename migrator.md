-- Migration function
-- Converts existing file text into smaller chunks stored in a separate "index" 
-- table

-- This function counts un-migrated files
-- Can be used manually to measure migration progress
CREATE OR REPLACE FUNCTION IS_MIGRATION_COMPLETE() RETURNS BOOLEAN
AS $migrate_file_tsvectors_remaining_count$
BEGIN
  RETURN (SELECT COUNT(*)=0 FROM files
            WHERE file_text_tsv IS NOT NULL
            AND file_text IS NOT NULL
            AND NOT(file_id IN (SELECT DISTINCT(file_id) 
                                FROM file_text_indices)));
END;
$migrate_file_tsvectors_remaining_count$
LANGUAGE plpgsql;

-- The actual migration function
-- Accepts an integer for how many files to migrate each run
-- Migrate most recent files first
-- Convert the larger file text into multiple smaller pieces stored in a separate 
-- "index" table

CREATE OR REPLACE FUNCTION migrate_file_tsvectors_to_file_indices
(num_files_in_batch INT) 
RETURNS BOOLEAN
AS $migrate_file_tsvectors_to_file_indices$
BEGIN
  INSERT INTO file_text_indices (file_id, content_tsv, content)
    SELECT file_id, to_tsvector(content), content
      FROM (SELECT file_id, LARGE_TEXT_TO_TSVECTORS(file_text) AS content
              FROM files AS f
              WHERE f.file_id IN (SELECT file_id FROM files
                                    WHERE file_text_tsv IS NOT NULL
                                    AND file_text IS NOT NULL
                                    AND NOT(file_id IN (SELECT DISTINCT(file_id) 
                                                        FROM file_text_indices))
                                  ORDER BY file_id DESC
                                  LIMIT num_files_in_batch)) AS file_frags
    WHERE content IS NOT NULL;

    RETURN IS_MIGRATION_COMPLETE();
END;
$migrate_file_tsvectors_to_file_indices$
LANGUAGE plpgsql;
