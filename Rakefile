require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "standard/rake"

task default: %i[spec:all standard]

require "active_record"
require "yaml"

namespace :db do
  desc "Create test database"
  task :create do
    config_path = ENV.fetch("DATABASE_CONFIG") { "spec/database.yml" }
    config = YAML.load_file(config_path)["test"]
    admin_config = config.merge("database" => "postgres")

    ActiveRecord::Base.establish_connection(admin_config)
    ActiveRecord::Base.connection.create_database(config["database"])
  end

  desc "Drop test database"
  task :drop do
    config_path = ENV.fetch("DATABASE_CONFIG") { "spec/database.yml" }
    config = YAML.load_file(config_path)["test"]
    admin_config = config.merge("database" => "postgres")

    ActiveRecord::Base.establish_connection(admin_config)
    ActiveRecord::Base.connection.drop_database(config["database"])
  end

  desc "Run migrations"
  task :migrate do
    config_path = ENV.fetch("DATABASE_CONFIG") { "spec/database.yml" }
    config = YAML.load_file(config_path)["test"]
    ActiveRecord::Base.establish_connection(config)

    ActiveRecord::Migration.verbose = true

    migrations_path = File.expand_path("spec/support/migrations", __dir__)
    migration_context = ActiveRecord::MigrationContext.new(migrations_path)

    migration_context.migrate
  end
end
