/* function: LTSV_LARGE_TEXT_TO_INDEXABLE_FRAGMENTS

Low-level implementation of string splitting for TSVector parsing
compliance. 

DO NOT CALL THESE FUNCTIONS DIRECTLY. 

Prefer: 
`LARGE_TEXT_TO_TSVECTORS ([REGCONFIG,] TEXT)`

Accepts string and left_overlap, the latter is the number of space-separated 
*/

-- 2-arity helper function not to be called directly
-- words
-- from the end of the previous string which the new string will contain
CREATE OR REPLACE FUNCTION LTSV_LARGE_TEXT_TO_INDEXABLE_FRAGMENTS
(string TEXT, left_overlap INT) 
RETURNS TABLE (fragment TEXT)
AS $$
DECLARE cutpoint INT;
DECLARE word_arr TEXT[];
BEGIN
  SELECT REGEXP_SPLIT_TO_ARRAY(string, '\s+') 
    INTO word_arr;

  SELECT LEAST(((ARRAY_LENGTH(word_arr, 1) + 1) / 2) + 1, 
               (2^14 - 2) - left_overlap) 
    INTO cutpoint;

  RETURN QUERY
  (SELECT array_to_string((word_arr)[(cutpoint * (idx - 1)) - (left_overlap - 1):
                                     (cutpoint * idx) 
                                     + (left_overlap 
                                        * (CASE WHEN (idx = 1) THEN 1 
                                           ELSE 0 
                                           END))], 
                          ' ')
     FROM generate_series(1, (ARRAY_LENGTH(word_arr, 1) / cutpoint) + 1) AS idx);
END;
$$
STABLE
LANGUAGE plpgsql;

-- A 1-arity helper function not to be called directly
-- Takes a string and splits it into many smaller chunks that match the TSVector 
-- limitations
-- Each will also overlap 32 words with the previous chunk
CREATE OR REPLACE FUNCTION LTSV_LARGE_TEXT_TO_INDEXABLE_FRAGMENTS
(string TEXT) 
RETURNS TABLE (fragment TEXT)
AS $$
DECLARE num_spaces INT;
BEGIN
  RETURN QUERY (SELECT LTSV_LARGE_TEXT_TO_INDEXABLE_FRAGMENTS(string, 32));
END;
$$
STABLE
LANGUAGE plpgsql;
