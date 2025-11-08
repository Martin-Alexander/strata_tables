module StrataTablesTest
  module TableFactory
    def table(name, as_of: false, **options, &block)
      if as_of
        as_of_table(name, **options, &block)
      else
        regular_table(name, **options, &block)
      end
    end

    def system_versioned_table(name, **options, &block)
      regular_table(name, **options, &block)

      ensure_btree_gist_enabled
      ensure_metadata_table_exists

      conn.create_history_table_for(name)
    end

    private

    def as_of_table(name, **options, &block)
      ensure_btree_gist_enabled

      options = options.merge(primary_key: [:id, :version_id])

      conn.create_table name, **options do |t|
        t.bigint :id
        t.bigserial :version_id
        t.tstzrange :period, null: false
        t.exclusion_constraint("id WITH =, period WITH &&", using: :gist)

        instance_exec(t, &block) if block
      end
    end

    def regular_table(name, **options, &block)
      conn.create_table name, **options do |t|
        instance_exec(t, &block) if block
      end

      Array(options[:primary_key] || :id).each do |col|
        randomize_sequence(name, col)
      end
    end

    def randomize_sequence(table, column)
      offset = Math.exp(2 + rand * (10 - 2)).to_i

      quoted_table_name = conn.quote_table_name(table)

      conn.execute(<<~SQL)
        SELECT setval(
          pg_get_serial_sequence('#{quoted_table_name}', '#{column}'),
          #{offset}
        )
      SQL
    end

    def ensure_btree_gist_enabled
      conn.enable_extension(:btree_gist) unless conn.extension_enabled?(:btree_gist)
    end

    def ensure_metadata_table_exists
      conn.create_strata_metadata_table unless conn.table_exists?(:strata_metadata)
    end
  end
end
