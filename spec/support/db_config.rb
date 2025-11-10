require "yaml"

module ActiveRecordTemporalTests
  class DbConfig
    class << self
      delegate :merge, to: :get

      def get
        db_config_path = ENV.fetch("DATABASE_CONFIG") { "spec/support/database.yml" }
        config = YAML.load_file(db_config_path) if File.exist?(db_config_path)
        config ||= {}
        default = {database: "activerecord_temporal_test"}

        default.merge(config).merge(adapter: :postgresql)
      end
    end
  end
end
