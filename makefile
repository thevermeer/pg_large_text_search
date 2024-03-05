

EXTENSION = pg_large_text_search
DATA = pg_large_text_search--1.0.sql
DIRECTORY = /sql
EXTENSION_NAME = pg_large_text_search
VERSION = 1.0
SCHEMA = public

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

.PHONY: all compile_sql

all: compile_sql

compile_sql:
	bash package.sh .$(DIRECTORY) $(DATA)
