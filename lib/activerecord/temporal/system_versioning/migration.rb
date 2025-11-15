module ActiveRecord::Temporal
  module SystemVersioning
    module Migration
      extend ActiveSupport::Concern

      included do
        prepend ActiveRecord::Temporal::SystemVersioning::SchemaStatements::CreateTableStatement
        prepend ActiveRecord::Temporal::SystemVersioning::SchemaStatements::DropTableStatement
      end
    end
  end
end
