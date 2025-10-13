require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "standard/rake"

task default: %i[spec standard]

require "active_record"
require_relative "spec/support/db_config"
require_relative "lib/strata_tables"

namespace :db do
  desc "Create test database"
  task :create do
    ActiveRecord::Base.establish_connection(DbConfig.merge(database: :postgres))
    ActiveRecord::Base.connection.create_database(:strata_tables_test)
  end

  desc "Drop test database"
  task :drop do
    ActiveRecord::Base.establish_connection(DbConfig.merge(database: :postgres))
    ActiveRecord::Base.connection.drop_database(:strata_tables_test)
  end

  desc "Run migrations"
  task :migrate do
    ActiveRecord::Base.establish_connection(DbConfig.get)

    ActiveRecord::Migration.verbose = true

    migrations_path = File.expand_path("spec/support/migrations", __dir__)
    migration_context = ActiveRecord::MigrationContext.new(migrations_path)

    migration_context.migrate
  end

  desc "Rollback migrations"
  task :rollback do
    ActiveRecord::Base.establish_connection(DbConfig.get)

    ActiveRecord::Migration.verbose = true

    migrations_path = File.expand_path("spec/support/migrations", __dir__)
    migration_context = ActiveRecord::MigrationContext.new(migrations_path)

    migration_context.rollback
  end
end
