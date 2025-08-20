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

In your base model include the model helpers:

```ruby
# app/models/application_record.rb
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  include StrataTables::Model
end
```

## Quick start

```ruby
class Product < ApplicationRecord
  has_many :line_items
end

class AddProductVersions < ActiveRecord::Migration[8.0]
  def change
    # Assuming you already have a `products` table

    create_temporal_table :products
  end
end
```

Now any insert/update/delete on `products` will update `products_versions`. The versions table mirrors the source columns and adds a non-null `validity` column of type `tstzrange` that captures the valid time range for each row version.

Read current and past versions:

```ruby
Product.versions
# => [
#   #<Product::Version
#     id: 1,
#     name: "Beach Umbrella",
#     price: 1299
#     validity: 2010-01-01 12:00:00 UTC...>,
#   #<Product::Version
#     id: 1,
#     name: "Beach Umbrella",
#     price: 2099,
#     validity: 2010-01-01 12:00:00 UTC...2010-01-01 12:00:10 UTC>,
#   #<Product::Version
#     id: 2,
#     name: "Portable Cooler",
#     price: 899
#     validity: 2010-01-01 2:00:00 UTC...>
# ]

Product.find(1).version
# => #<Product::Version
#      id: 1
#      name: "Beach Umbrella",
#      price: 1299,
#      validity: 2010-01-01 12:00:00 UTC...>
```

Time-travel queries ("as of" reads):

```ruby
# Make the helper available where you want to call it (e.g., controllers/services)
class ApplicationController < ActionController::Base
  include StrataTables
end

# Query data from accossiations as it were one hour
as_of_scope(1.hour.ago) do
  Product::Version.find_by(name: "Beach Umbrella").line_items
end
```

## Contributing

After checking out the repo, run `rake db:create db:migrate` to set up the PostgreSQL test database. Then run `rspec`.
