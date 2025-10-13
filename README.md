# Strata Tables

Temporal tables for Active Record. This gem automatically maintains a companion `*__history` table for a source table and keeps it up to date via database triggers. It also provides convenient model helpers for querying historical data and "as of" time-travel reads.

See also:
- https://en.wikipedia.org/wiki/Temporal_database
- https://wiki.postgresql.org/wiki/Temporal_Extensions

Expanded documentation is forthcoming.

## Requirements

- Active Record >= 7
- PostgreSQL >= 9

## Quick start

Use custom schema statements to create history tables for existing tables. In this example say we have a `products` table and a `categories` table.


```ruby
class CreateHistoryTableForAuthorsAndBooks < ActiveRecord::Migration[8.0]
  def change
    # This will enable temporal exclusion constraints to be generated
    enable_extension :btree_gist

    create_history_table :products, copy_data: true

    # Omit certain columns from the history table
    create_history_table :categories, copy_data: true, except: [:updated_at]
  end
end
```

New history tables will have the same columns as their source table in addition to a `version_id` primary key and `sys_period` for tracking when the row was valid from a system perspective.

For an existing `products` tables, the SQL produced will be roughly equivalent to:

```sql
CREATE TABLE products__history (
    version_id bigint NOT NULL,
    id bigint NOT NULL,
    name character varying,
    price integer,
    category_id bigint,
    sys_period tstzrange NOT NULL
);

ALTER TABLE ONLY products__history ADD CONSTRAINT excl_rails_42e30d1c5d EXCLUDE
  USING gist (id WITH =, sys_period WITH &&);
ALTER TABLE ONLY products__history ADD CONSTRAINT products__history_pkey
  PRIMARY KEY (version_id);

CREATE FUNCTION products__history_delete() RETURNS trigger LANGUAGE plpgsql AS $$
  BEGIN
    UPDATE "products__history" SET sys_period = tstzrange(lower(sys_period), now())
    WHERE id = OLD.id AND upper_inf(sys_period);

    RETURN NULL;
  END;
$$;

CREATE FUNCTION products__history_insert() RETURNS trigger LANGUAGE plpgsql AS $$
  BEGIN
    INSERT INTO "products__history" (id, name, price, category_id, sys_period)
    VALUES (NEW.id, NEW.name, NEW.price, NEW.category_id, tstzrange(now(), NULL));

    RETURN NULL;
  END;
$$;

CREATE FUNCTION products__history_update() RETURNS trigger LANGUAGE plpgsql AS $$
  BEGIN
    IF OLD IS NOT DISTINCT FROM NEW THEN
      RETURN NULL;
    END IF;

    UPDATE "products__history" SET sys_period = tstzrange(lower(sys_period), now())
    WHERE id = OLD.id AND upper_inf(sys_period);

    INSERT INTO "products__history" (id, name, price, category_id, sys_period)
    VALUES (NEW.id, NEW.name, NEW.price, NEW.category_id, tstzrange(now(), NULL));

    RETURN NULL;
  END;
$$;

CREATE TRIGGER on_delete AFTER DELETE ON products
  FOR EACH ROW EXECUTE FUNCTION products__history_delete();
CREATE TRIGGER on_insert AFTER INSERT ON products
  FOR EACH ROW EXECUTE FUNCTION products__history_insert();
CREATE TRIGGER on_update AFTER UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION products__history_update();
```

Include `StrataTables::Model` to enable models to be used in historical querying. Models without a history table can also be used, buy they'll be treated as though all their records have always existed.

```ruby
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  include StrataTables::Model
end

time = 1.day.ago
# => 2025-10-13 19:00:00 UTC

product = Product.as_of(time).where("price > 100").first
# Product::Version Load (1.2ms)  SELECT "products__history".* FROM "products__history" WHERE ("products__history"."sys_period" @> $1::timestamptz) AND (price > 100) ORDER BY "products__history"."version_id" ASC LIMIT $2  [[nil, "2025-10-13 19:00:00"], ["LIMIT", 1]]
# => #<Product::Version
#  version_id: 3,
#  id: 3,
#  name: "Zepbound",
#  price: 349,
#  category_id: 2,
#  sys_period: 2025-10-13 18:24:39.807499 UTC...>

product.category
# Category::Version Load (0.5ms)  SELECT "categories__history".* FROM "categories__history" WHERE "categories__history"."id" = $1 AND ("categories__history"."sys_period" @> $2::timestamptz) LIMIT $3  [["id", 2], [nil, "2025-10-13 19:00:00"], ["LIMIT", 1]]
# => #<Category::Version
#  version_id: 2,
#  id: 2,
#  name: "Weight Loss",
#  sys_period: 2025-10-13 18:24:39.807499 UTC...> 
```

## Contributing

After checking out the repo, run `rake db:create db:migrate` to set up the PostgreSQL test database. Then run `rake`.
