# Strata Tables

Temporal tables for ActiveRecord. This gem automatically maintains a companion `*__history` table for a source table and keeps it up to date via database triggers. It also provides convenient model helpers for querying historical data and "as of" time-travel reads.

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

    create_history_table :products

    create_table :books do |t|
      t.string :title
      t.references :authors, null: false, foreign_key: true
    end

    create_history_table :books
  end
end
```

```
          Table "public.authors"
╔════════╤═══════════════════╤══════════╗
║ Column │       Type        │ Nullable ║
╠════════╪═══════════════════╪══════════╣
║ id     │ bigint            │ not null ║
║ name   │ character varying │          ║
╚════════╧═══════════════════╧══════════╝
Indexes:
    "authors_pkey" PRIMARY KEY, btree (id)
Triggers:
    on_delete_strata_trigger AFTER DELETE ON authors FOR EACH ROW EXECUTE
FUNCTION authors__history_delete()
    on_insert_strata_trigger AFTER INSERT ON authors FOR EACH ROW EXECUTE
FUNCTION authors__history_insert()
    on_update_strata_trigger AFTER UPDATE ON authors FOR EACH ROW EXECUTE
FUNCTION authors__history_update()

            Table "public.authors__history"
╔════════════╤═══════════════════╤══════════╗
║   Column   │       Type        │ Nullable ║
╠════════════╪═══════════════════╪══════════╣
║ version_id │ bigint            │ not null ║
║ id         │ bigint            │ not null ║
║ name       │ character varying │          ║
║ validity   │ tstzrange         │ not null ║
╚════════════╧═══════════════════╧══════════╝
Indexes:
    "authors__history_pkey" PRIMARY KEY, btree (version_id)

            Table "public.books"
╔═══════════╤═══════════════════╤══════════╗
║  Column   │       Type        │ Nullable ║
╠═══════════╪═══════════════════╪══════════╣
║ id        │ bigint            │ not null ║
║ title     │ character varying │          ║
║ author_id │ bigint            │          ║
╚═══════════╧═══════════════════╧══════════╝
Indexes:
    "books_pkey" PRIMARY KEY, btree (id)
    "index_books_on_author_id" btree (author_id)
Triggers:
    on_delete_strata_trigger AFTER DELETE ON books FOR EACH ROW EXECUTE FUNCTION
books__history_delete()
    on_insert_strata_trigger AFTER INSERT ON books FOR EACH ROW EXECUTE FUNCTION
books__history_insert()
    on_update_strata_trigger AFTER UPDATE ON books FOR EACH ROW EXECUTE FUNCTION
books__history_update()

         Table "public.books__history"
╔════════════╤═══════════════════╤══════════╗
║   Column   │       Type        │ Nullable ║
╠════════════╪═══════════════════╪══════════╣
║ version_id │ bigint            │ not null ║
║ id         │ bigint            │ not null ║
║ title      │ character varying │          ║
║ author_id  │ bigint            │          ║
║ validity   │ tstzrange         │ not null ║
╚════════════╧═══════════════════╧══════════╝
Indexes:
    "books__history_pkey" PRIMARY KEY, btree (version_id)

```

Now any insert/update/delete on `books` will update `books__history`. The history table mirrors the source columns and adds a non-null `validity` column of type `tstzrange` that captures the valid time range for each row version.

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
  FROM authors__history
WHERE authors__history.validity @> '2024-12-01 00:00:00 UTC'::timestamptz

-- authors.first.books
SELECT *
  FROM books__history
WHERE books__history.validity @> '2024-12-01 00:00:00 UTC'::timestamptz
  AND books__history.author_id = 1

-- Book.as_of(t1).includes(:author).where(authors: { id: authors.first.id })
SELECT *
  FROM books__history
LEFT OUTER JOIN authors__history
  ON authors__history.id = books__history.author_id
  AND books__history.validity @> '2024-12-01 00:00:00 UTC'::timestamptz
WHERE authors__history.validity @> '2024-12-01 00:00:00 UTC'::timestamptz
  AND books__history.author_id = 1
```

## Contributing

After checking out the repo, run `rake db:create db:migrate` to set up the PostgreSQL test database. Then run `rspec`.
