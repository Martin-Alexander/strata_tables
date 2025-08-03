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

namespace :dummy_app do
  desc "Create dummy app"
  task :create do
    options = %w[
      -q
      --database=postgresql
      --skip-action-cable
      --skip-action-mailbox
      --skip-action-mailer
      --skip-action-text
      --skip-active-storage
      --skip-asset-pipeline
      --skip-bootsnap
      --skip-brakeman
      --skip-ci
      --skip-decrypted-diffs
      --skip-dev-gems
      --skip-docker
      --skip-git
      --skip-hotwire
      --skip-javascript
      --skip-jbuilder
      --skip-kamal
      --skip-listen
      --skip-rubocop
      --skip-solid
      --skip-spring
      --skip-system-test
      --skip-test
      --skip-thruster
    ]
    FileUtils.mkdir_p("tmp/dummy_app")
    Dir.chdir("tmp") do
      FileUtils.rm_rf("dummy_app")
      sh "rails new dummy_app #{options.join(" ")}"
    end

    Dir.chdir("tmp/dummy_app") do
      sh "rails db:create"

      File.open("Gemfile", "a") do |f|
        f.puts 'gem "history_tables", path: "../../"'
      end

      sh "bundle install"
    end
  end
end

namespace :spec do
  desc "Run ActiveRecord-only tests"
  task unit: ["db:drop", "db:create", "db:migrate"] do
    sh "rspec spec/history_tables_spec.rb"
  end

  desc "Run Rails integration tests"
  task integration: "dummy_app:create" do
    sh "rspec spec/dummy_app_spec.rb"
  end

  desc "Run all tests (unit + integration)"
  task :all do
    Rake::Task["spec:unit"].invoke
    Rake::Task["spec:integration"].invoke
  end
end
