module StrataTablesTest
  module TableFactory
    def table(name, as_of: false, &block)
      as_of ? as_of_table(name, &block) : regular_table(name, &block)
    end

    def system_versioned_table(name, **options, &block)
      regular_table(name, **options, &block)

      conn.enable_extension(:btree_gist) unless conn.extension_enabled?(:btree_gist)
      conn.create_strata_metadata_table unless conn.table_exists?(:strata_metadata)
      conn.create_history_table_for(name)
    end

    def as_of_table(name, &block)
      conn.enable_extension(:btree_gist) unless conn.extension_enabled?(:btree_gist)

      conn.create_table name, primary_key: [:id, :period_start] do |t|
        t.bigint :id
        t.tstzrange :period, null: false
        t.virtual :period_start,
          type: :timestamptz,
          as: "lower(period)",
          stored: true
        t.virtual :period_end,
          type: :timestamptz,
          as: "upper(period)",
          stored: true
        t.exclusion_constraint("id WITH =, period WITH &&", using: :gist)

        instance_exec(t, &block) if block
      end
    end

    def regular_table(name, **options, &block)
      conn.create_table name, **options do |t|
        instance_exec(t, &block) if block
      end

      randomize_sequence(name, :id)
    end

    def randomize_sequence(table, column)
      offset = Math.exp(2 + rand * (10 - 2)).to_i

      conn.execute(<<~SQL)
        SELECT setval(pg_get_serial_sequence('#{conn.quote_table_name(table)}', '#{column}'), #{offset})
      SQL
    end
  end
end
