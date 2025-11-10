require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "standard/rake"
require "active_record"
require_relative "spec/support/db_config"

RSpec::Core::RakeTask.new(:spec)

task default: %i[spec standard]

namespace :db do
  include ActiveRecordTemporalTests

  desc "Create test database"
  task :create do
    ActiveRecord::Base.establish_connection(DbConfig.merge(database: :postgres))
    ActiveRecord::Base.connection.create_database(:activerecord_temporal_test)
  end

  desc "Drop test database"
  task :drop do
    ActiveRecord::Base.establish_connection(DbConfig.merge(database: :postgres))
    ActiveRecord::Base.connection.drop_database(:activerecord_temporal_test)
  end
end
