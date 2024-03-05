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
