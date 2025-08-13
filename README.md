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

### Setup for Demo

1. Create a category called "DVDs & VHS"
2. Create a product called "Titanic" and assign it to the category we just created
3. Update the category's name to "Movies"
4. Create another product called "Gattaca" and assign it to the same category
5. Create a category called "Video"
6. Make this new category the parent of the movies category
7. Destroy the titanic product

```ruby
t0 = Time.now
# => 2010-01-01 0:00

first_category = Category.create(name: "DVDs & VHS")
# => #<Category id: 1, name: "DVDs & VHS", parent_id: nil>

t1 = Time.now
# => 2010-01-01 1:00

titanic = Product.create(name: "Titanic", price: 799, category: first_category)
# => #<Product id: 1, name: "Titanic", price: 799, category_id: 1>

t2 = Time.now
# => 2010-01-01 2:00

first_category.update(name: "Movies")
# => true

t3 = Time.now
# => 2010-01-01 3:00

gattaca = Product.create(name: "Gattaca", price: 799, category: first_category)
# => #<Product id: 2, name: "Gattaca", price: 799, category_id: 1>

t4 =  Time.now
# => 2010-01-01 4:00

gattaca.update(price: 299)
# => true

t5 =  Time.now
# => 2010-01-01 5:00

parent_category = Category.create(name: "Video")
# => #<Category id: 2, name: "Video", parent_id: nil>

t6 = Time.now
# => 2010-01-01 6:00

first_category.update(parent: parent_category)
# => true

t7 = Time.now
# => 2010-01-01 7:00

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
    #<Category id: 1, name: "Movies", parent_id: 2>,
    #<Category id: 2, name: "Video", parent_id: nil>
# ]
```

### History

```ruby
snapshot_at(t2) { Category::Snapshot.find(1) }
# => #<Category::Snapshot
#      id: 1,
#      name: "DVDs & VHS",
#      parent_id: nil,
#      validity: 2010-01-01 0:00...2010-01-01 2:00>

snapshot_at(t2) { Products::Snapshot.where(category_id: 1) }
# => [
#      #<Product::Snapshot
#        id: 1,
#        name: "Titanic",
#        price: 799,
#        category_id 1,
#        validity: 2010-01-01 1:00...2010-01-01 7:00>
# ]
```

### Schema

```sql
CREATE TABLE public.categories (
    id bigint NOT NULL,
    name character varying NOT NULL,
    parent_id bigint
);

CREATE TABLE public.strata_categories (
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