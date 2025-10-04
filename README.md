# Strata Tables

Temporal tables for ActiveRecord. This gem automatically maintains a companion `*_versions` table for a source table and keeps it up to date via database triggers. It also provides convenient model helpers for querying historical data and "as of" time-travel reads.

## Requirements

- Ruby >= 3.2
- ActiveRecord >= 7.0, < 9.0
- PostgreSQL (with the `pg` gem)

## Installation

Add to your Gemfile and bundle:

```ruby
gem "strata_tables"
```

## Quick start

```ruby
class Author < ActiveRecord::Base
  has_many :books
end

class Book < ActiveRecord::Base
  belongs_to :author
end

class CreateAuthorsAndBooks < ActiveRecord::Migration[8.0]
  def change
    create_table :authors do |t|
      t.string :name
    end

    create_temporal_table :products

    create_table :books do |t|
      t.string :title
      t.references :authors, null: false, foreign_key: true
    end

    create_temporal_table :books
  end
end
```

```
                                  Table "public.authors"
╔════════╤═══════════════════╤═══════════╤══════════╤═════════════════════════════════════╗
║ Column │       Type        │ Collation │ Nullable │               Default               ║
╠════════╪═══════════════════╪═══════════╪══════════╪═════════════════════════════════════╣
║ id     │ bigint            │           │ not null │ nextval('authors_id_seq'::regclass) ║
║ name   │ character varying │           │          │                                     ║
╚════════╧═══════════════════╧═══════════╧══════════╧═════════════════════════════════════╝
Indexes:
    "authors_pkey" PRIMARY KEY, btree (id)
Triggers:
    on_delete_strata_trigger AFTER DELETE ON authors FOR EACH ROW EXECUTE FUNCTION authors_versions_delete()
    on_insert_strata_trigger AFTER INSERT ON authors FOR EACH ROW EXECUTE FUNCTION authors_versions_insert()
    on_update_strata_trigger AFTER UPDATE ON authors FOR EACH ROW EXECUTE FUNCTION authors_versions_update()

                                        Table "public.authors_versions"
╔════════════╤═══════════════════╤═══════════╤══════════╤══════════════════════════════════════════════════════╗
║   Column   │       Type        │ Collation │ Nullable │                       Default                        ║
╠════════════╪═══════════════════╪═══════════╪══════════╪══════════════════════════════════════════════════════╣
║ version_id │ bigint            │           │ not null │ nextval('authors_versions_version_id_seq'::regclass) ║
║ id         │ bigint            │           │ not null │                                                      ║
║ name       │ character varying │           │          │                                                      ║
║ validity   │ tstzrange         │           │ not null │                                                      ║
╚════════════╧═══════════════════╧═══════════╧══════════╧══════════════════════════════════════════════════════╝
Indexes:
    "authors_versions_pkey" PRIMARY KEY, btree (version_id)

                                    Table "public.books"
╔═══════════╤═══════════════════╤═══════════╤══════════╤═══════════════════════════════════╗
║  Column   │       Type        │ Collation │ Nullable │              Default              ║
╠═══════════╪═══════════════════╪═══════════╪══════════╪═══════════════════════════════════╣
║ id        │ bigint            │           │ not null │ nextval('books_id_seq'::regclass) ║
║ title     │ character varying │           │          │                                   ║
║ author_id │ bigint            │           │          │                                   ║
╚═══════════╧═══════════════════╧═══════════╧══════════╧═══════════════════════════════════╝
Indexes:
    "books_pkey" PRIMARY KEY, btree (id)
    "index_books_on_author_id" btree (author_id)
Triggers:
    on_delete_strata_trigger AFTER DELETE ON books FOR EACH ROW EXECUTE FUNCTION books_versions_delete()
    on_insert_strata_trigger AFTER INSERT ON books FOR EACH ROW EXECUTE FUNCTION books_versions_insert()
    on_update_strata_trigger AFTER UPDATE ON books FOR EACH ROW EXECUTE FUNCTION books_versions_update()

                                        Table "public.books_versions"
╔════════════╤═══════════════════╤═══════════╤══════════╤════════════════════════════════════════════════════╗
║   Column   │       Type        │ Collation │ Nullable │                      Default                       ║
╠════════════╪═══════════════════╪═══════════╪══════════╪════════════════════════════════════════════════════╣
║ version_id │ bigint            │           │ not null │ nextval('books_versions_version_id_seq'::regclass) ║
║ id         │ bigint            │           │ not null │                                                    ║
║ title      │ character varying │           │          │                                                    ║
║ author_id  │ bigint            │           │          │                                                    ║
║ validity   │ tstzrange         │           │ not null │                                                    ║
╚════════════╧═══════════════════╧═══════════╧══════════╧════════════════════════════════════════════════════╝
Indexes:
    "books_versions_pkey" PRIMARY KEY, btree (version_id)

```

Now any insert/update/delete on `books` will update `bookss_versions`. The versions table mirrors the source columns and adds a non-null `validity` column of type `tstzrange` that captures the valid time range for each row version.

Find author records as they were 10 months ago:

```ruby
t1 = 10.months.ago
# => 2024-12-01 00:00:00 UTC

authors = Author.as_of(t1.ago)
# => [
#   #<Author::Version
#     version_id: 1,
#     id: 1,
#     name: "Bob",
#     validity: 2022-01-01 00:00:00 UTC...2025-06-10 00:00:00 UTC>,
#   #<Author::Version
#     version_id: 3,
#     id: 2,
#     name: "Jim",
#     validity: 2020-08-10 00:00:00 UTC...>
# ]
```

Records returned from queries using `as_of` will carry it over to their assocaiations

```ruby
authors.first.books
# => [
#   #<Book::Version
#     version_id: 9,
#     id: 1,
#     name: "Calliou",
#     author_id: 1,
#     validity: 2023-10-01 00:00:00 UTC...2025-06-10 00:00:00 UTC>,
#   #<Book::Version
#     id: 2,
#     name: "Big Red",
#     author_id: 1,
#     validity: 2023-10-05 00:00:00 UTC...2025-06-10 00:00:00 UTC>
# ]
```

Use where clauses, joins, scopes, eager loading, grouping, aggregations, etc.

```ruby
Book.as_of(t1).includes(:author).where(authors: { id: authors.first.id })
# => [
#   #<Book::Version
#     version_id: 9,
#     id: 1,
#     name: "Calliou",
#     author_id: 1,
#     validity: 2023-10-01 00:00:00 UTC...2025-06-10 00:00:00 UTC>,
#   #<Book::Version
#     id: 2,
#     name: "Big Red",
#     author_id: 1,
#     validity: 2023-10-05 00:00:00 UTC...2025-06-10 00:00:00 UTC>
# ]
```

The queries above would produce SQL that looks roughly something like this:

```sql
-- authors = Author.as_of(t1.ago)
SELECT *
  FROM authors_versions
WHERE authors_versions.validity @> '2024-12-01 00:00:00 UTC'::timestamptz

-- authors.first.books
SELECT *
  FROM books_versions
WHERE books_versions.validity @> '2024-12-01 00:00:00 UTC'::timestamptz
  AND books_versions.author_id = 1

-- Book.as_of(t1).includes(:author).where(authors: { id: authors.first.id })
SELECT *
  FROM books_versions
LEFT OUTER JOIN authors_versions
  ON authors_versions.id = books_versions.author_id
  AND books_versions.validity @> '2024-12-01 00:00:00 UTC'::timestamptz
WHERE authors_versions.validity @> '2024-12-01 00:00:00 UTC'::timestamptz
  AND books_versions.author_id = 1
```

## Contributing

After checking out the repo, run `rake db:create db:migrate` to set up the PostgreSQL test database. Then run `rspec`.
