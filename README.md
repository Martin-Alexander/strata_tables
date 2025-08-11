# StrataTables

```ruby
create_table :categories do |t|
  t.string :name, null: false
  t.references :parent, foreign_key: {to_table: :categories}
end

create_table :products do |t|
  t.string :name, null: false
  t.references :category, foreign_key: true, index: true
end

create_strata_table :categories
create_strata_table :products
```

```sql
CREATE TABLE public.categories (
    id bigint NOT NULL,
    name character varying NOT NULL,
    parent_id bigint
);

CREATE TABLE public.strata_categories (
    hid bigint NOT NULL,
    id bigint NOT NULL,
    name character varying NOT NULL,
    parent_id bigint,
    validity tsrange NOT NULL
);

CREATE OR REPLACE FUNCTION public.strata_categories_delete()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
  BEGIN
    UPDATE "strata_categories"
    SET validity = tsrange(lower(validity), timezone('UTC', now()))
    WHERE id = OLD.id
      AND upper_inf(validity);
    RETURN NULL;
  END;
$function$

CREATE OR REPLACE FUNCTION public.strata_categories_insert()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
  BEGIN
    INSERT INTO "strata_categories" (id, name, parent_id, validity)
    VALUES (NEW.id, NEW.name, NEW.parent_id, tsrange(timezone('UTC', now()), NULL));
    RETURN NULL;
  END;
$function$

CREATE OR REPLACE FUNCTION public.strata_categories_update()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
  BEGIN
    IF OLD IS NOT DISTINCT FROM NEW THEN
      RETURN NULL;
    END IF;
    UPDATE "strata_categories"
    SET validity = tsrange(lower(validity), timezone('UTC', now()))
    WHERE id = OLD.id
      AND upper_inf(validity);
    INSERT INTO "strata_categories" (id, name, parent_id, validity)
    VALUES (NEW.id, NEW.name, NEW.parent_id, tsrange(timezone('UTC', now()), NULL));
    RETURN NULL;
  END;
$function$

CREATE TABLE public.products (
    id bigint NOT NULL,
    name character varying NOT NULL,
    price integer NOT NULL,
    category_id bigint
);

CREATE TABLE public.strata_products (
    hid bigint NOT NULL,
    id bigint NOT NULL,
    name character varying NOT NULL,
    price integer NOT NULL,
    category_id bigint,
    validity tsrange NOT NULL
);

CREATE OR REPLACE FUNCTION public.strata_products_delete()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
  BEGIN
    UPDATE "strata_products"
    SET validity = tsrange(lower(validity), timezone('UTC', now()))
    WHERE id = OLD.id
      AND upper_inf(validity);
    RETURN NULL;
  END;
$function$

CREATE OR REPLACE FUNCTION public.strata_products_insert()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
  BEGIN
    INSERT INTO "strata_products" (id, name, price, category_id, validity)
    VALUES (NEW.id, NEW.name, NEW.price, NEW.category_id, tsrange(timezone('UTC', now()), NULL));
    RETURN NULL;
  END;
$function$

CREATE OR REPLACE FUNCTION public.strata_products_update()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
  BEGIN
    IF OLD IS NOT DISTINCT FROM NEW THEN
      RETURN NULL;
    END IF;
    UPDATE "strata_products"
    SET validity = tsrange(lower(validity), timezone('UTC', now()))
    WHERE id = OLD.id
      AND upper_inf(validity);
    INSERT INTO "strata_products" (id, name, price, category_id, validity)
    VALUES (NEW.id, NEW.name, NEW.price, NEW.category_id, tsrange(timezone('UTC', now()), NULL));
    RETURN NULL;
  END;
$function$
```

### Setup for Demo

1. Create a category called "DVDs & VHS"
2. Create a product called "Titanic" and assign it to the category we just created
3. Update the category's name to "Home Video"
4. Create another product called "Gattaca" an assign it to the same category
5. Create a category called "Entertainment"
6. Make this new category the parent of the home video category
7. Destroy the titanic product

```ruby
t0 = Time.now
# => 2010-01-01 0:00:00 UTC

first_category = Category.create(name: "DVDs & VHS")
# => #<Category id: 1, name: "DVDs & VHS", parent_id: nil>

t1 = Time.now
# => 2010-01-01 1:00:00 UTC

titanic = Product.create(name: "Titanic", price: 799, category: first_category)
# => #<Product id: 1, name: "Titanic", price: 799, category_id: 1>

t2 = Time.now
# => 2010-01-01 2:00:00 UTC

first_category.update(name: "Home Video")
# => true

t3 = Time.now
# => 2010-01-01 3:00:00 UTC

gattaca = Product.create(name: "Gattaca", price: 799, category: first_category)
# => #<Product id: 2, name: "Gattaca", price: 799, category_id: 1>

t4 =  Time.now
# => 2010-01-01 4:00:00 UTC

gattaca.update(price: 299)
# => true

t5 =  Time.now
# => 2010-01-01 5:00:00 UTC

parent_category = Category.create(name: "Entertainment")
# => #<Category id: 2, name: "Entertainment", parent_id: nil>

t6 = Time.now
# => 2010-01-01 6:00:00 UTC

first_category.update(parent: parent_category)
# => true

t7 = Time.now
# => 2010-01-01 7:00:00 UTC

titanic.destroy # too soon?
# => #<Product id: 1, name: "Titanic", price: 799, category_id: 1>
```

### Current State

```ruby
Product.all
# => [
    #<Product id: 2, name: "Gattaca", price: 299, category_id: 1>
# ]

Category.all
# => [
    #<Category id: 1, name: "Home Video", parent_id: 2>,
    #<Category id: 2, name: "Entertainment", parent_id: nil>
# ]
```

### History

Call `#history` to get its `Lifetime`. This represents the full history of a given record and contains all its versions
and the time span in which it existed.

```ruby
first_category.history
# => #<Category::Lifetime item_id: 1, versions: 3, span: 2010-01-01 1:00:01 UTC...>
```

Versions have the primary key `hid`, and `validity` is the range of time the version was valid for. Ranges without an
end indicate that the version is the current version.

```ruby
first_category.history.versions
# => [
    #<Category::Version hid: 1, id: 1, name: "DVDs & VHS", parent_id: nil, validity: 2010-01-01 1:00:01 UTC...2010-01-01 2:00:01 UTC>,
    #<Category::Version hid: 2, id: 1, name: "Home Video", parent_id: nil, validity: 2010-01-01 2:00:01 UTC...2010-01-01 6:00:01 UTC>,
    #<Category::Version hid: 4, id: 1, name: "Home Video", parent_id: 2,   validity: 2010-01-01 6:00:01 UTC...>,
# ]
```

Passing a time into `#snapshot_at` will return a snapshot. These are like versions, but with at a specific point of time
within thier validity range (passing in a time outside a version's validity range will return an error).

Although a version will, by definition, be the same at any point in it's validity range, associated records can vary. So
this is useful for exploring associations at a specific point in time.

```ruby
category_snapshot_1 = first_category.history.snapshot_at(t2)
# => #<Category::Snapshot at: "2010-01-01 2:00:00 UTC", hid: 1, id: 1, name: "DVDs & VHS", parent_id: nil, validity: 2010-01-01 0:00:01 UTC...2010-01-01 2:00:01 UTC>

category_snapshot_1.products
# => [
    #<Product::Snapshot at: "2010-01-01 2:00:00 UTC", hid: 1, id: 1, name: "Titanic", price: 799, category_id 1, validity: 2010-01-01 1:00:01 UTC...2010-01-01 7:00:01 UTC>
# ]

gattaca.history.snapshot_at(t5).category.parent
# => nil

gattaca.history.snapshot_at(t7).category.parent
# => #<Category::Version hid: 5, id: 2, name: "Entertainment", parent_id: nil, validity: 2010-01-01 5:00:01 UTC...>
```

Extinct records can be found by the ID they had when they existed.

```ruby
titanic_lifetime = Product::Lifetime.find(1)
# => #<Product::Lifetime item_id: 1, versions 1, span: 2010-01-01 1:00:01 UTC...2010-01-01 7:00:01 UTC>

titanic_lifetime.versions.first
# => #<Product::Version hid: 1, id: 1, name: "Titanic", price: 799, category_id 1, validity: 2010-01-01 1:00:01 UTC...2010-01-01 7:00:01 UTC>
```
