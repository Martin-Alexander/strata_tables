require "yaml"

class DbConfig
  class << self
    delegate :merge, to: :get

    def get
      db_config_path = ENV.fetch("DATABASE_CONFIG") { "spec/support/database.yml" }
      config = YAML.load_file(db_config_path) if File.exist?(db_config_path)
      config ||= {}
      default = {database: "strata_tables_test"}

      default.merge(config).merge(adapter: :postgresql)
    end
  end
end
