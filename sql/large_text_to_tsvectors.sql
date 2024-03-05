/* function: LARGE_TEXT_TO_TSVECTORS

Separate long strings into smaller strings, each of which will parse to 
valid and conformant tsvectors.
- Need to avoid all of these issues: 
  https://www.postgresql.org/docs/14/textsearch-limitations.html
- Higher-level function to handle the details of separating long text into 
  smaller pieces for TSVectors.

Returns a recordset of strings, each of which is plain text for a valid TSVector
For indexing, We store both the text and a TSVector, in case we need to 
consult the original text later, or want to use the built-in TS_HEADLINE, or
eventually, TS_SEMANTIC_HEADLINE and TS_FAST HEADLINE
*/
CREATE OR REPLACE FUNCTION LARGE_TEXT_TO_TSVECTORS
(config REGCONFIG, source TEXT) 
RETURNS TABLE (content_fragment TEXT) AS 
$$
DECLARE vector TSVECTOR = TO_TSVECTOR(config, source);
BEGIN
  IF (vector = ''::TSVECTOR) THEN
    -- A trivial TSV, return the original text
    RETURN QUERY (SELECT source);
    -- If we have a text smaller than 256 words, it doesn't need to be divided 
    -- anymore. In some cases the other branch was recurring infinitely.
  ELSIF ( ARRAY_LENGTH(REGEXP_SPLIT_TO_ARRAY(source, E'\\s+'), 1) < 2^8 ) THEN
    RETURN QUERY (SELECT source);
  ELSIF (SELECT
         -- Prevent any positions larger than 16382; since the cap is 16383
         -- and more than 1 lexeme can occupy position 16383.
          ( SELECT MAX(terms.pos)
              FROM (SELECT UNNEST((words).positions) AS pos
                      FROM (SELECT words 
                              FROM (SELECT UNNEST(vector) AS words) 
                                    AS lexes) 
                            AS wordplaces) 
                    AS terms)
            > (2 ^14 - 2)
            OR
            -- Prevent any specific lexeme occurring more than 255 times
            ( SELECT MAX(ARRAY_LENGTH((lex_position_arrays.words).positions, 1))
                FROM (SELECT words 
                        FROM (SELECT UNNEST(vector) AS words)
                              AS lexes) 
                      AS lex_position_arrays)
            > (2 ^ 8 - 2))
  THEN
    -- Recur
    RETURN QUERY (SELECT LARGE_TEXT_TO_TSVECTORS(config, fragment) 
                  FROM LTSV_LARGE_TEXT_TO_INDEXABLE_FRAGMENTS(source));
  ELSE
    -- If it's already or eventually valid, return unchanged
    RETURN QUERY (SELECT source);
  END IF;

-- ** EXCEPTION HANDLING ::
-- If we try to create a TSVector and it's too large, make it smaller and try 
-- again
EXCEPTION WHEN program_limit_exceeded THEN
  -- Recur
  RETURN QUERY (SELECT LARGE_TEXT_TO_TSVECTORS(config, fragment) 
                FROM LTSV_LARGE_TEXT_TO_INDEXABLE_FRAGMENTS(source));
END;
$$
STABLE
LANGUAGE plpgsql;
