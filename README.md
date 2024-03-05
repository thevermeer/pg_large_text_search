# Large-scale Full Text Search for PostgreSQL
Herein are a few simple tools for creating a well-formed index for large documents within PostgreSQL full-text search

## Purpose
Using PostgreSQL for full-text search can be fruitful, and the many built-in text search functions provide a powerful start to developing a search and recall system.

That said, postgreSQL has a number of significant limitations to how it builds `TSVECTOR` lookup indexes for full-text search, and these limitations quickly emerge when indexing large text files. The notion of what makes a large text file is objectively defined my the TSVector limitations as text containing more than 16,383 (2^14 - 1) words, wshere the position ordinal in the TSVECTOR is of type `SMALLINT` and thusly limited in maximum value.

## PostgreSQL Limitiations Managed by this Extension
Considering [[PostgreSQL Text Search Limitations](https://www.postgresql.org/docs/14/textsearch-limitations.html)], there are a few big gotchas when trying to index large text. From the manual: 
>> The current limitations of PostgreSQL's text search features are:
   - The length of each lexeme must be less than 2 kilobytes
   - The length of a tsvector (lexemes + positions) must be less than 1 megabyte
   - The number of lexemes must be less than 264
   - Position values in tsvector must be greater than 0 and no more than 16,383
   - The match distance in a <N> (FOLLOWED BY) tsquery operator cannot be more than 16,384
   - No more than 256 positions per lexeme
   - The number of nodes (lexemes + operators) in a tsquery must be less than 32,768

The most pressing limitations for large text indexing are:
   - The number of lexemes must be less than 264
   - Position values in tsvector must be greater than 0 and no more than 16,383
   - No more than 256 positions per lexeme

## Prerequisites
- PostgreSQL@14 or greater.

## Installation
This project is in development February/April of 2024. Before we have a stable release version, if you wish to run the extension:

1) Clone this repository.

2) `cd` into the project directory `/pg_large_text_serarch`

3) Run `make && make install` :
- `make` - will compile the source files in the `/sql` folder into a single .sql file as the extention.
- `make install` - will copy the _compiled_ (concatenated :)) .sql file into your PGSQL extensions directory. eg. `/usr/local/share/postgresql@14/extension/`

4) In your target Postgres database, run `CREATE EXTENSION PG_LARGE_TEXT_SEARCH;`

## Usage
The extension provides the `LARGE_TEXT_TO_TSVECTORS ([config REGCONFIG,] source TEXT)` for splitting a given text into fragments, each of which will form a valid TSVector. Additionally, the fragments will overlap by n words, in order to create better phrase recognition across the fragment boundaries.

`LARGE_TEXT_TO_TSVECTORS` will return a table/recordset of TEXT fragments. and those fragments in turn can be:
- Saved to a data table as a text fragment
- Used to render a TSVector; the TSVector can then be saved to a data table and used for fast lookup of fuzzy, language-gnostic search.
- Used to render a TEXT[] array of content for fast content retrieval.

For a large text, given by content, we can split the text into n fragments determined against TSVector limitations by the function, by invoking:
```
SELECT LARGE_TEXT_TO_TSVECTORS(content);
```
### Building a Content Index Table
Typically, PostgreSQL full-text search demands that TSVectors are pre-realized and stored to a table for performant lookup. In order to index large texts, we are going to create an index and lookup table. For each of the `files` table that we want to index, we will end up splitting the source text to n pieces and storing each of the fragmented indices.

So, if we are to start with a files table that looks like:
```
CREATE TABLE files (
  file_id SERIAL PRIMARY KEY,
  content TEXT
);
```

We will create a seconbd table to store our n well-formed TSVector indexes:
```
CREATE TABLE file_text_indices (
  file_text_index_id SERIAL PRIMARY KEY,
  file_id INTEGER NOT NULL REFERENCES files(file_id) ON DELETE CASCADE,
  sequence_no INTEGER NOT NULL,
  content_tsv TSVECTOR,
  content TEXT,
  -- Optional Content Array for fast text recall
  -- See: https://github.com/thevermeer/pg_ts_semantic_headline for more information
  content_arr TEXT[]
);
```
Now, when we either `INSERT` or `UPDATE` to the `files` to files, we are going to want to ensure that the novel text is fragmented into TSVector-friendly pieces and saves to the `file_text_indices` table.

### Triggering Automatic Update of file_text_indices
In order to automate the synchronizing and updating of `files`->`file_text_indices`, we first create a psql `TRIGGER` that will take the new text added to the `files` table, split it with `LARGE_TEXT_TO_TSVECTORS`, and save each of the resultant substrings to the `file_text_indices` table:
```
-- Separate long strings into smaller tsvectors
-- Need to avoid all of these issues: 
   https://www.postgresql.org/docs/14/textsearch-limitations.html
-- Trigger Function for AFTER UPDATE/INSERT on file_text
-- Clear any existing TSVector records, and add the smaller chunks to the index
CREATE OR REPLACE FUNCTION tfn_split_file_to_indices() RETURNS trigger
AS $$
DECLARE num_spaces INT;
BEGIN
  DELETE FROM file_text_indices WHERE file_id = NEW.file_id;

  INSERT INTO file_text_indices (file_id, content_tsv, content)
  SELECT file_id, to_tsvector(content), content
    FROM (SELECT NEW.file_id, LARGE_TEXT_TO_TSVECTORS(NEW.file_text) as content) AS frags
   WHERE content IS NOT NULL;

  RETURN NULL;
END;
$$
LANGUAGE plpgsql;
```

Next, we will apply a `TRIGGER` on the `files` table `AFTER INSERT OR UPDATE`: 
```
-- Add the trigger to the files table file_text column
CREATE TRIGGER t_update_file_text_tsv
AFTER INSERT OR UPDATE OF content ON files
FOR EACH ROW EXECUTE FUNCTION split_file_text_to_file_indices();
```

That's that! From this point, we only need to add or update content in the `files` table to then split our content into n well-formed TSVectors for fast lookup.
